// Lambda function to handle EC2 Spot Instance interruption notifications
// This function is triggered by SNS notifications when a Spot Instance is about to be interrupted
// It performs graceful shutdown procedures to ensure work is saved and processing can be resumed

const AWS = require('aws-sdk');
const CHECKPOINT_INTERVAL_SECONDS = 60; // How often checkpoints should be created during processing

exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    try {
        // Parse the SNS message
        const message = JSON.parse(event.Records[0].Sns.Message);
        console.log('Parsed message:', JSON.stringify(message, null, 2));

        // Extract instance ID and interruption time
        const instanceId = message.detail['instance-id'];
        const interruptionTime = message.detail['instance-action'];

        console.log(`Spot Instance ${instanceId} will be interrupted at ${interruptionTime}`);

        // Configure AWS SDK
        const ec2 = new AWS.EC2({ region: process.env.REGION });
        const s3 = new AWS.S3();
        const dynamodb = new AWS.DynamoDB.DocumentClient();

        // Get instance details
        const instanceResponse = await ec2.describeInstances({
            InstanceIds: [instanceId]
        }).promise();

        if (!instanceResponse.Reservations || instanceResponse.Reservations.length === 0) {
            throw new Error(`Instance ${instanceId} not found`);
        }

        const instance = instanceResponse.Reservations[0].Instances[0];
        const tags = instance.Tags || [];

        // Find any processing job information from tags
        const jobIdTag = tags.find(tag => tag.Key === 'JobId');
        const jobId = jobIdTag ? jobIdTag.Value : null;

        if (jobId) {
            console.log(`Found job ID ${jobId} for instance ${instanceId}`);

            // Update job status in DynamoDB
            await dynamodb.update({
                TableName: process.env.JOBS_TABLE || 'video-super-resolution-jobs',
                Key: { jobId: jobId },
                UpdateExpression: 'SET jobStatus = :status, interruptedAt = :time, interruptedInstanceId = :instanceId',
                ExpressionAttributeValues: {
                    ':status': 'INTERRUPTED',
                    ':time': new Date().toISOString(),
                    ':instanceId': instanceId
                }
            }).promise();

            // Execute SSM command to gracefully save work
            const ssm = new AWS.SSM();
            const commandResponse = await ssm.sendCommand({
                InstanceIds: [instanceId],
                DocumentName: 'AWS-RunShellScript',
                Parameters: {
                    commands: [
                        '#!/bin/bash',
                        'set -e', // Exit immediately if a command exits with a non-zero status
                        'echo "Spot instance interruption detected, performing graceful shutdown"',

                        // Create a timestamp for this checkpoint
                        'TIMESTAMP=$(date +"%Y%m%d%H%M%S")',

                        // Save current progress to S3
                        'if [ -f /tmp/current_job_id ]; then',
                        '  JOB_ID=$(cat /tmp/current_job_id)',
                        '  echo "Saving progress for job $JOB_ID"',
                        '  # Create a checkpoint directory',
                        '  mkdir -p /tmp/checkpoint_$TIMESTAMP',

                        '  # Stop any running processing tasks gracefully',
                        '  if pgrep -f "python.*process_frames" > /dev/null; then',
                        '    echo "Stopping frame processing tasks..."',
                        '    pkill -SIGTERM -f "python.*process_frames" || echo "No process to kill"',
                        '    # Wait for processes to terminate gracefully',
                        '    sleep 5',
                        '    # Force kill if still running',
                        '    pkill -SIGKILL -f "python.*process_frames" 2>/dev/null || echo "All processes terminated"',
                        '  fi',

                        '  # Upload any processed frames to S3',
                        '  if [ -d /tmp/processed_frames ]; then',
                        '    echo "Syncing processed frames to S3..."',
                        '    aws s3 sync /tmp/processed_frames s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/processed_frames/ --quiet',
                        '    # Create a manifest of processed frames',
                        '    find /tmp/processed_frames -type f -name "*.png" | sort > /tmp/checkpoint_$TIMESTAMP/processed_frames_manifest.txt',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/processed_frames_manifest.txt s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/checkpoints/$TIMESTAMP/processed_frames_manifest.txt --quiet',
                        '  fi',

                        '  # Save job state',
                        '  if [ -f /tmp/job_state.json ]; then',
                        '    echo "Saving job state to S3..."',
                        '    # Make a copy with timestamp',
                        '    cp /tmp/job_state.json /tmp/checkpoint_$TIMESTAMP/job_state.json',
                        '    # Add interruption information to job state (requires jq)',
                        '    INTERRUPT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
                        '    jq --arg time "$INTERRUPT_TIME" --arg checkpoint "$TIMESTAMP" \'. + {"interrupted": true, "interruptedAt": $time, "checkpointId": $checkpoint}\' /tmp/job_state.json > /tmp/checkpoint_$TIMESTAMP/job_state_updated.json',
                        '    # Upload both versions',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/job_state_updated.json s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/job_state.json --quiet',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/job_state_updated.json s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/checkpoints/$TIMESTAMP/job_state.json --quiet',
                        '  else',
                        '    # Create a basic job state file if none exists',
                        '    INTERRUPT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
                        '    echo "{\\"jobId\\": \\"$JOB_ID\\", \\"interrupted\\": true, \\"interruptedAt\\": \\"$INTERRUPT_TIME\\", \\"checkpointId\\": \\"$TIMESTAMP\\"}" > /tmp/checkpoint_$TIMESTAMP/job_state.json',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/job_state.json s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/job_state.json --quiet',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/job_state.json s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/checkpoints/$TIMESTAMP/job_state.json --quiet',
                        '  fi',

                        '  # Save logs',
                        '  if [ -d /var/log/video-processing ]; then',
                        '    echo "Saving processing logs to S3..."',
                        '    tar -czf /tmp/checkpoint_$TIMESTAMP/processing_logs.tar.gz -C /var/log/video-processing .',
                        '    aws s3 cp /tmp/checkpoint_$TIMESTAMP/processing_logs.tar.gz s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/checkpoints/$TIMESTAMP/processing_logs.tar.gz --quiet',
                        '  fi',

                        '  # Create a checkpoint completion marker',
                        '  COMPLETE_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
                        '  echo "Checkpoint completed at $COMPLETE_TIME" > /tmp/checkpoint_$TIMESTAMP/checkpoint_complete.txt',
                        '  aws s3 cp /tmp/checkpoint_$TIMESTAMP/checkpoint_complete.txt s3://' + process.env.S3_BUCKET_NAME + '/jobs/$JOB_ID/checkpoints/$TIMESTAMP/checkpoint_complete.txt --quiet',

                        '  echo "Progress saved for job $JOB_ID with checkpoint ID $TIMESTAMP"',
                        '  # Clean up checkpoint directory',
                        '  rm -rf /tmp/checkpoint_$TIMESTAMP',
                        'else',
                        '  echo "No current job found"',
                        'fi',

                        'echo "Graceful shutdown completed"',
                        'exit 0' // Ensure the script exits with success
                    ]
                }
            }).promise();

            // Store the command ID for later reference
            const commandId = commandResponse.Command.CommandId;
            console.log(`SSM command ${commandId} sent to instance ${instanceId}`);

            // Check current fleet capacity and request replacement if needed
            if (process.env.FLEET_ID) {
                // Get current fleet capacity
                const fleetResponse = await ec2.describeSpotFleetRequests({
                    SpotFleetRequestIds: [process.env.FLEET_ID]
                }).promise();

                if (fleetResponse.SpotFleetRequestConfigs && fleetResponse.SpotFleetRequestConfigs.length > 0) {
                    const fleet = fleetResponse.SpotFleetRequestConfigs[0];
                    const currentCapacity = fleet.SpotFleetRequestConfig.FulfilledCapacity || 0;
                    const targetCapacity = parseInt(process.env.TARGET_CAPACITY || '2');

                    console.log(`Current fleet capacity: ${currentCapacity}, Target capacity: ${targetCapacity}`);

                    // Enhanced fallback mechanism to on-demand instances
                    // Calculate the percentage of fulfilled capacity
                    const fulfillmentPercentage = (currentCapacity / targetCapacity) * 100;
                    console.log(`Fleet fulfillment: ${fulfillmentPercentage.toFixed(2)}% (${currentCapacity}/${targetCapacity})`);

                    // Define thresholds for different fallback strategies
                    const severeShortageThreshold = 50; // Below 50% is severe
                    const moderateShortageThreshold = 80; // Below 80% is moderate

                    let onDemandCount = 0;
                    let fallbackStrategy = 'none';

                    if (fulfillmentPercentage < severeShortageThreshold) {
                        // Severe shortage: Aggressively use on-demand instances to maintain capacity
                        // Use on-demand for most of the missing capacity
                        onDemandCount = Math.ceil((targetCapacity - currentCapacity) * 0.75);
                        fallbackStrategy = 'aggressive';
                    } else if (fulfillmentPercentage < moderateShortageThreshold) {
                        // Moderate shortage: Use a balanced approach
                        // Use on-demand for about half of the missing capacity
                        onDemandCount = Math.ceil((targetCapacity - currentCapacity) * 0.5);
                        fallbackStrategy = 'balanced';
                    } else {
                        // Minor or no shortage: Minimal on-demand usage
                        // Use on-demand only for a small portion of the missing capacity
                        onDemandCount = Math.ceil((targetCapacity - currentCapacity) * 0.25);
                        fallbackStrategy = 'minimal';
                    }

                    // Ensure we have at least 1 on-demand instance if we need any fallback
                    if (currentCapacity < targetCapacity && onDemandCount < 1) {
                        onDemandCount = 1;
                    }

                    // Log the fallback strategy
                    console.log(`Using ${fallbackStrategy} fallback strategy with ${onDemandCount} on-demand instances`);

                    // Update the fleet configuration
                    await ec2.modifySpotFleetRequest({
                        SpotFleetRequestId: process.env.FLEET_ID,
                        TargetCapacity: targetCapacity,
                        OnDemandTargetCapacity: onDemandCount
                    }).promise();

                    console.log(`Modified fleet ${process.env.FLEET_ID}: target=${targetCapacity}, on-demand=${onDemandCount}`);

                    // Record the fallback action in DynamoDB if we have a job
                    if (jobId) {
                        await dynamodb.update({
                            TableName: process.env.JOBS_TABLE || 'video-super-resolution-jobs',
                            Key: { jobId: jobId },
                            UpdateExpression: 'SET fallbackStrategy = :strategy, onDemandCount = :count, lastFallbackTime = :time',
                            ExpressionAttributeValues: {
                                ':strategy': fallbackStrategy,
                                ':count': onDemandCount,
                                ':time': new Date().toISOString()
                            }
                        }).promise();
                    }
                }
            }
        } else {
            console.log(`No job ID found for instance ${instanceId}, no specific action needed`);
        }

        return {
            statusCode: 200,
            body: JSON.stringify({
                message: `Successfully processed interruption for instance ${instanceId}`,
                instanceId: instanceId,
                jobId: jobId
            })
        };
    } catch (error) {
        console.error('Error processing spot interruption:', error);
        throw error;
    }
};
