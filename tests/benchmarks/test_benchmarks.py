import pytest
import os
import sys

# Add the current directory to the path so we can import the benchmark_pipeline module
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from benchmark_pipeline import PipelineBenchmark

def test_benchmark_pipeline():
    """Test that the benchmark pipeline can run successfully."""
    # Create a benchmark instance with minimal configuration for testing
    benchmark = PipelineBenchmark()

    # Test a single video with a single model and just one iteration
    benchmark.config['test_videos'] = [
        {'name': 'test_video.mp4', 'resolution': '480p', 'duration': 2}
    ]
    benchmark.config['models'] = ['realesrgan']
    benchmark.config['iterations'] = 1

    # Run the benchmark
    results = benchmark.run_benchmarks()

    # Verify that results were generated
    assert results is not None
    assert len(results) == 1
    assert results[0]['video_name'] == 'test_video.mp4'
    assert results[0]['model'] == 'realesrgan'
    assert results[0]['total_time'] > 0
