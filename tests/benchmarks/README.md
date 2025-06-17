# Video Super-Resolution Pipeline Benchmarking

This directory contains tools for benchmarking the performance of the video super-resolution pipeline. The benchmarking framework allows you to measure the performance of different components of the pipeline, compare different AI models, and analyze the impact of video characteristics on processing time.

## Overview

The benchmarking framework consists of the following components:

1. **Benchmark Pipeline Script** (`benchmark_pipeline.py`): The main script for running end-to-end pipeline benchmarks.
2. **Benchmark Configuration** (`benchmark_config.json`): Configuration file for customizing benchmark parameters.
3. **Results Directory**: Generated benchmark results and visualizations are stored in the `results` directory.

## Getting Started

### Prerequisites

- Python 3.7+
- Required Python packages: `boto3`, `matplotlib`, `numpy`, `pandas`
- Access to AWS resources (S3 buckets, etc.) if running with real data

### Installation

Install the required Python packages:

```bash
pip install boto3 matplotlib numpy pandas
```

### Running Benchmarks

To run a benchmark with the default configuration:

```bash
python benchmark_pipeline.py
```

To run a benchmark with a custom configuration:

```bash
python benchmark_pipeline.py --config custom_config.json --output-dir custom_results
```

## Configuration

The benchmark configuration file (`benchmark_config.json`) allows you to customize various aspects of the benchmarking process:

- **S3 Buckets**: Specify the source, processed, and final buckets for video data.
- **Test Videos**: Define a set of test videos with different resolutions and durations.
- **Models**: Configure the AI models to benchmark (RealESRGAN, SwinIR, etc.).
- **Iterations**: Set the number of iterations for statistical significance.
- **Metrics**: Specify which performance metrics to measure.
- **Output Formats**: Choose the formats for benchmark results (JSON, CSV, PNG).

Example configuration:

```json
{
  "source_bucket": "source-bucket",
  "processed_bucket": "processed-bucket",
  "final_bucket": "final-bucket",
  "test_videos": [
    {
      "name": "small_video.mp4",
      "resolution": "480p",
      "duration": 5,
      "description": "Small test video (480p, 5 seconds)"
    }
  ],
  "models": [
    {
      "name": "realesrgan",
      "description": "Real-ESRGAN model for super-resolution",
      "parameters": {
        "scale": 4,
        "model_name": "RealESRGAN_x4plus"
      }
    }
  ],
  "iterations": 3,
  "metrics": [
    "frame_extraction_time",
    "super_resolution_time",
    "video_recomposition_time",
    "total_time"
  ],
  "output_formats": [
    "json",
    "csv",
    "png"
  ]
}
```

## Benchmark Results

After running a benchmark, the following outputs are generated in the results directory:

1. **JSON Report**: A detailed report of all benchmark results in JSON format.
2. **Visualizations**: Charts and graphs visualizing the benchmark results:
   - Bar chart of total processing time by video and model
   - Stacked bar chart of processing stages by video and model
   - Line chart of processing time vs. video duration

## Interpreting Results

The benchmark results provide insights into the performance characteristics of the video super-resolution pipeline:

- **Processing Time by Stage**: Identify which stages of the pipeline (frame extraction, super-resolution, video recomposition) are the most time-consuming.
- **Model Comparison**: Compare the performance of different AI models (RealESRGAN vs. SwinIR).
- **Scaling Behavior**: Understand how processing time scales with video duration and resolution.
- **Resource Usage**: Analyze CPU, memory, and GPU usage during processing.

## Extending the Framework

The benchmarking framework can be extended in several ways:

1. **Add New Metrics**: Implement additional performance metrics in the `PipelineBenchmark` class.
2. **Benchmark Specific Components**: Create specialized benchmark scripts for specific pipeline components.
3. **Real-World Testing**: Replace the simulated processing with actual pipeline execution for real-world performance measurements.

## Troubleshooting

If you encounter issues with the benchmarking framework:

1. **Check AWS Credentials**: Ensure that your AWS credentials are properly configured if running with real S3 buckets.
2. **Verify Dependencies**: Make sure all required Python packages are installed.
3. **Check Permissions**: Ensure that the benchmark script has permission to create files in the output directory.
4. **Increase Verbosity**: Add more print statements to the benchmark script for debugging.

## Contributing

Contributions to the benchmarking framework are welcome! Please follow these steps:

1. Create a new branch for your changes.
2. Implement your changes and test them thoroughly.
3. Submit a pull request with a clear description of your changes.