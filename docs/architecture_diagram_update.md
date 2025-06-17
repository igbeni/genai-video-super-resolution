# Architecture Diagram Update Instructions

## Overview
This document provides instructions for updating the architecture diagram to reflect the S3-only storage approach instead of FSx for Lustre.

## Current Architecture
The current architecture diagram (`img/genai-video-super-resolution-architecture.png`) shows a solution that uses Amazon FSx for Lustre as a shared file system across all compute nodes. However, the architecture has been updated to use S3-only storage with efficient access patterns and local caching mechanisms.

## Required Changes
The following changes should be made to the architecture diagram:

1. **Remove FSx for Lustre**: Remove any references to FSx for Lustre from the diagram.

2. **Add S3 Storage Components**:
   - Add S3 buckets for source videos, processed frames, and final videos
   - Add S3 lifecycle policies for intermediate artifacts
   - Add S3 storage classes (Standard, IA, Glacier)
   - Add S3 access patterns (multipart uploads, presigned URLs)
   - Add local caching mechanisms

3. **Update Data Flow**:
   - Update the data flow to show how data moves between S3 and compute nodes
   - Show how the pipeline uses S3 for all storage needs

4. **Add Cost Optimization Components**:
   - Add EC2 Spot Instance strategy
   - Add automatic scaling down of idle instances
   - Add SageMaker endpoint shutdown after processing
   - Add resource leak monitoring

5. **Add Security Components**:
   - Add IAM roles with least privilege
   - Add VPC endpoints for S3 access
   - Add encryption for data at rest and in transit

6. **Add Monitoring Components**:
   - Add CloudWatch dashboards for cost tracking
   - Add CloudWatch alarms for failures and performance issues
   - Add SNS notifications for critical events
   - Add CloudTrail for API activity logging

## Design Guidelines
- Use AWS architecture icons from the [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/) library
- Follow the same style and color scheme as the current diagram
- Keep the diagram clean and easy to understand
- Include a legend to explain the components and data flow

## Tools
You can use the following tools to create the updated architecture diagram:
- [AWS Architecture Diagrams](https://aws.amazon.com/architecture/reference-architecture-diagrams/)
- [draw.io](https://app.diagrams.net/) (with AWS icons)
- [Lucidchart](https://www.lucidchart.com/) (with AWS icons)

## Output
Save the updated architecture diagram as `img/genai-video-super-resolution-architecture.png` to replace the current diagram.