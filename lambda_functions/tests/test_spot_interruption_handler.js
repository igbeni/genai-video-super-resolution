// Unit tests for spot_interruption_handler.js using Jest
const AWS = require('aws-sdk');
const handler = require('../spot_interruption_handler').handler;

// Mock AWS SDK
jest.mock('aws-sdk');

describe('Spot Interruption Handler', () => {
    // Setup environment variables
    const originalEnv = process.env;
    
    beforeEach(() => {
        // Reset environment variables before each test
        process.env = {
            ...originalEnv,
            REGION: 'us-east-1',
            JOBS_TABLE: 'test-jobs-table',
            S3_BUCKET_NAME: 'test-bucket',
            FLEET_ID: 'sfr-12345',
            TARGET_CAPACITY: '2'
        };
        
        // Clear all mocks
        jest.clearAllMocks();
        
        // Setup AWS SDK mocks
        mockEC2();
        mockS3();
        mockDynamoDB();
        mockSSM();
    });
    
    afterAll(() => {
        // Restore original environment
        process.env = originalEnv;
    });
    
    test('should handle spot interruption notification successfully', async () => {
        // Create test event
        const event = createSpotInterruptionEvent('i-12345', '2023-06-01T00:00:00Z');
        
        // Call the handler
        const result = await handler(event, {});
        
        // Verify the result
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).instanceId).toBe('i-12345');
        expect(JSON.parse(result.body).jobId).toBe('job-123');
        
        // Verify DynamoDB was updated
        expect(AWS.DynamoDB.DocumentClient.prototype.update).toHaveBeenCalledWith(
            expect.objectContaining({
                TableName: 'test-jobs-table',
                Key: { jobId: 'job-123' },
                UpdateExpression: expect.stringContaining('jobStatus = :status')
            })
        );
        
        // Verify SSM command was sent
        expect(AWS.SSM.prototype.sendCommand).toHaveBeenCalledWith(
            expect.objectContaining({
                InstanceIds: ['i-12345'],
                DocumentName: 'AWS-RunShellScript'
            })
        );
        
        // Verify fleet was modified
        expect(AWS.EC2.prototype.modifySpotFleetRequest).toHaveBeenCalledWith(
            expect.objectContaining({
                SpotFleetRequestId: 'sfr-12345',
                TargetCapacity: 2
            })
        );
    });
    
    test('should handle instance without job ID', async () => {
        // Mock EC2 to return instance without JobId tag
        AWS.EC2.prototype.describeInstances = jest.fn().mockReturnValue({
            promise: jest.fn().mockResolvedValue({
                Reservations: [
                    {
                        Instances: [
                            {
                                InstanceId: 'i-12345',
                                Tags: [
                                    { Key: 'Name', Value: 'test-instance' }
                                ]
                            }
                        ]
                    }
                ]
            })
        });
        
        // Create test event
        const event = createSpotInterruptionEvent('i-12345', '2023-06-01T00:00:00Z');
        
        // Call the handler
        const result = await handler(event, {});
        
        // Verify the result
        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body).instanceId).toBe('i-12345');
        expect(JSON.parse(result.body).jobId).toBeNull();
        
        // Verify DynamoDB was not updated
        expect(AWS.DynamoDB.DocumentClient.prototype.update).not.toHaveBeenCalled();
        
        // Verify SSM command was not sent
        expect(AWS.SSM.prototype.sendCommand).not.toHaveBeenCalled();
    });
    
    test('should handle severe capacity shortage with aggressive fallback', async () => {
        // Mock EC2 to return low fleet capacity
        AWS.EC2.prototype.describeSpotFleetRequests = jest.fn().mockReturnValue({
            promise: jest.fn().mockResolvedValue({
                SpotFleetRequestConfigs: [
                    {
                        SpotFleetRequestConfig: {
                            FulfilledCapacity: 0.5  // 25% of target capacity (2)
                        }
                    }
                ]
            })
        });
        
        // Create test event
        const event = createSpotInterruptionEvent('i-12345', '2023-06-01T00:00:00Z');
        
        // Call the handler
        const result = await handler(event, {});
        
        // Verify the result
        expect(result.statusCode).toBe(200);
        
        // Verify fleet was modified with aggressive fallback strategy
        expect(AWS.EC2.prototype.modifySpotFleetRequest).toHaveBeenCalledWith(
            expect.objectContaining({
                SpotFleetRequestId: 'sfr-12345',
                TargetCapacity: 2,
                OnDemandTargetCapacity: 2  // Should request more on-demand instances for severe shortage
            })
        );
        
        // Verify fallback strategy was recorded in DynamoDB
        expect(AWS.DynamoDB.DocumentClient.prototype.update).toHaveBeenCalledWith(
            expect.objectContaining({
                TableName: 'test-jobs-table',
                Key: { jobId: 'job-123' },
                UpdateExpression: expect.stringContaining('fallbackStrategy = :strategy')
            })
        );
    });
    
    test('should handle moderate capacity shortage with balanced fallback', async () => {
        // Mock EC2 to return moderate fleet capacity
        AWS.EC2.prototype.describeSpotFleetRequests = jest.fn().mockReturnValue({
            promise: jest.fn().mockResolvedValue({
                SpotFleetRequestConfigs: [
                    {
                        SpotFleetRequestConfig: {
                            FulfilledCapacity: 1.5  // 75% of target capacity (2)
                        }
                    }
                ]
            })
        });
        
        // Create test event
        const event = createSpotInterruptionEvent('i-12345', '2023-06-01T00:00:00Z');
        
        // Call the handler
        const result = await handler(event, {});
        
        // Verify the result
        expect(result.statusCode).toBe(200);
        
        // Verify fleet was modified with balanced fallback strategy
        expect(AWS.EC2.prototype.modifySpotFleetRequest).toHaveBeenCalledWith(
            expect.objectContaining({
                SpotFleetRequestId: 'sfr-12345',
                TargetCapacity: 2,
                OnDemandTargetCapacity: 1  // Should request fewer on-demand instances for moderate shortage
            })
        );
    });
    
    test('should handle error in AWS API calls', async () => {
        // Mock EC2 to throw an error
        AWS.EC2.prototype.describeInstances = jest.fn().mockReturnValue({
            promise: jest.fn().mockRejectedValue(new Error('AWS API Error'))
        });
        
        // Create test event
        const event = createSpotInterruptionEvent('i-12345', '2023-06-01T00:00:00Z');
        
        // Call the handler and expect it to throw
        await expect(handler(event, {})).rejects.toThrow('AWS API Error');
    });
    
    test('should handle invalid event format', async () => {
        // Create invalid event
        const event = { Records: [] };
        
        // Call the handler and expect it to throw
        await expect(handler(event, {})).rejects.toThrow();
    });
});

// Helper functions to create test data and mock AWS services

function createSpotInterruptionEvent(instanceId, interruptionTime) {
    return {
        Records: [
            {
                Sns: {
                    Message: JSON.stringify({
                        detail: {
                            'instance-id': instanceId,
                            'instance-action': interruptionTime
                        }
                    })
                }
            }
        ]
    };
}

function mockEC2() {
    // Mock EC2 describe instances
    AWS.EC2.prototype.describeInstances = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({
            Reservations: [
                {
                    Instances: [
                        {
                            InstanceId: 'i-12345',
                            Tags: [
                                { Key: 'JobId', Value: 'job-123' },
                                { Key: 'Name', Value: 'test-instance' }
                            ]
                        }
                    ]
                }
            ]
        })
    });
    
    // Mock EC2 describe spot fleet requests
    AWS.EC2.prototype.describeSpotFleetRequests = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({
            SpotFleetRequestConfigs: [
                {
                    SpotFleetRequestConfig: {
                        FulfilledCapacity: 2.0  // 100% of target capacity
                    }
                }
            ]
        })
    });
    
    // Mock EC2 modify spot fleet request
    AWS.EC2.prototype.modifySpotFleetRequest = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({})
    });
}

function mockS3() {
    // Mock S3 operations (not directly used in the handler but might be in the SSM command)
    AWS.S3.prototype.putObject = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({})
    });
}

function mockDynamoDB() {
    // Mock DynamoDB update
    AWS.DynamoDB.DocumentClient.prototype.update = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({})
    });
}

function mockSSM() {
    // Mock SSM send command
    AWS.SSM.prototype.sendCommand = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({
            Command: {
                CommandId: 'cmd-12345'
            }
        })
    });
}