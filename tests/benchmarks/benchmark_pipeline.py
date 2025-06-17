import os
import time
import json
import boto3
import argparse
import statistics
import matplotlib.pyplot as plt
from datetime import datetime

# Add the lambda_functions directory to the path so we can import the Lambda functions
import sys
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'lambda_functions'))

class PipelineBenchmark:
    """Benchmark the video super-resolution pipeline performance"""
    
    def __init__(self, config_file=None, output_dir=None):
        """Initialize the benchmark with configuration"""
        self.start_time = None
        self.end_time = None
        self.stage_times = {}
        self.metrics = {}
        
        # Set default output directory
        if output_dir is None:
            self.output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results')
        else:
            self.output_dir = output_dir
            
        # Create output directory if it doesn't exist
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Load configuration if provided
        if config_file:
            with open(config_file, 'r') as f:
                self.config = json.load(f)
        else:
            # Default configuration
            self.config = {
                'source_bucket': 'source-bucket',
                'processed_bucket': 'processed-bucket',
                'final_bucket': 'final-bucket',
                'test_videos': [
                    {'name': 'small_video.mp4', 'resolution': '480p', 'duration': 5},
                    {'name': 'medium_video.mp4', 'resolution': '720p', 'duration': 10},
                    {'name': 'large_video.mp4', 'resolution': '1080p', 'duration': 30}
                ],
                'models': ['realesrgan', 'swinir'],
                'iterations': 3
            }
    
    def start_timer(self, stage=None):
        """Start timing a stage or the overall benchmark"""
        if stage:
            self.stage_times[stage] = {'start': time.time()}
        else:
            self.start_time = time.time()
    
    def end_timer(self, stage=None):
        """End timing a stage or the overall benchmark"""
        if stage:
            if stage in self.stage_times:
                self.stage_times[stage]['end'] = time.time()
                self.stage_times[stage]['duration'] = self.stage_times[stage]['end'] - self.stage_times[stage]['start']
                return self.stage_times[stage]['duration']
            else:
                print(f"Warning: Stage '{stage}' was not started")
                return None
        else:
            self.end_time = time.time()
            return self.end_time - self.start_time
    
    def benchmark_frame_extraction(self, video_info):
        """Benchmark the frame extraction process"""
        self.start_timer('frame_extraction')
        
        # Simulate frame extraction process
        # In a real benchmark, this would call the actual frame extraction code
        # or measure a real execution
        
        # For simulation, we'll use a formula based on video size
        duration = video_info['duration']
        resolution_factor = 1.0
        if video_info['resolution'] == '720p':
            resolution_factor = 2.0
        elif video_info['resolution'] == '1080p':
            resolution_factor = 4.0
            
        # Simulate processing time (in seconds)
        processing_time = duration * resolution_factor * 0.5
        time.sleep(min(processing_time, 2))  # Cap at 2 seconds for simulation
        
        extraction_time = self.end_timer('frame_extraction')
        return extraction_time
    
    def benchmark_super_resolution(self, video_info, model):
        """Benchmark the super resolution process"""
        self.start_timer('super_resolution')
        
        # Simulate super resolution process
        # In a real benchmark, this would call the actual super resolution code
        # or measure a real execution
        
        # For simulation, we'll use a formula based on video size and model
        duration = video_info['duration']
        resolution_factor = 1.0
        if video_info['resolution'] == '720p':
            resolution_factor = 2.0
        elif video_info['resolution'] == '1080p':
            resolution_factor = 4.0
            
        model_factor = 1.0
        if model == 'swinir':
            model_factor = 1.5  # SwinIR is typically slower
            
        # Simulate processing time (in seconds)
        processing_time = duration * resolution_factor * model_factor * 2.0
        time.sleep(min(processing_time, 3))  # Cap at 3 seconds for simulation
        
        sr_time = self.end_timer('super_resolution')
        return sr_time
    
    def benchmark_video_recomposition(self, video_info):
        """Benchmark the video recomposition process"""
        self.start_timer('video_recomposition')
        
        # Simulate video recomposition process
        # In a real benchmark, this would call the actual video recomposition code
        # or measure a real execution
        
        # For simulation, we'll use a formula based on video size
        duration = video_info['duration']
        resolution_factor = 1.0
        if video_info['resolution'] == '720p':
            resolution_factor = 2.0
        elif video_info['resolution'] == '1080p':
            resolution_factor = 4.0
            
        # Simulate processing time (in seconds)
        processing_time = duration * resolution_factor * 0.8
        time.sleep(min(processing_time, 2))  # Cap at 2 seconds for simulation
        
        recomposition_time = self.end_timer('video_recomposition')
        return recomposition_time
    
    def benchmark_end_to_end(self, video_info, model):
        """Benchmark the end-to-end pipeline"""
        self.start_timer()
        
        # Run each stage of the pipeline
        extraction_time = self.benchmark_frame_extraction(video_info)
        sr_time = self.benchmark_super_resolution(video_info, model)
        recomposition_time = self.benchmark_video_recomposition(video_info)
        
        # Calculate total time
        total_time = self.end_timer()
        
        # Return metrics
        return {
            'video_name': video_info['name'],
            'resolution': video_info['resolution'],
            'duration': video_info['duration'],
            'model': model,
            'frame_extraction_time': extraction_time,
            'super_resolution_time': sr_time,
            'video_recomposition_time': recomposition_time,
            'total_time': total_time
        }
    
    def run_benchmarks(self):
        """Run all benchmarks according to configuration"""
        results = []
        
        for video in self.config['test_videos']:
            for model in self.config['models']:
                print(f"Benchmarking {video['name']} with {model} model...")
                
                # Run multiple iterations for statistical significance
                iteration_results = []
                for i in range(self.config['iterations']):
                    print(f"  Iteration {i+1}/{self.config['iterations']}...")
                    result = self.benchmark_end_to_end(video, model)
                    iteration_results.append(result)
                
                # Calculate average metrics across iterations
                avg_result = {
                    'video_name': video['name'],
                    'resolution': video['resolution'],
                    'duration': video['duration'],
                    'model': model,
                    'frame_extraction_time': statistics.mean([r['frame_extraction_time'] for r in iteration_results]),
                    'super_resolution_time': statistics.mean([r['super_resolution_time'] for r in iteration_results]),
                    'video_recomposition_time': statistics.mean([r['video_recomposition_time'] for r in iteration_results]),
                    'total_time': statistics.mean([r['total_time'] for r in iteration_results])
                }
                
                results.append(avg_result)
                print(f"  Average total time: {avg_result['total_time']:.2f} seconds")
        
        self.metrics['results'] = results
        return results
    
    def generate_report(self):
        """Generate a performance report from benchmark results"""
        if not self.metrics.get('results'):
            print("No benchmark results available. Run benchmarks first.")
            return
        
        # Create timestamp for the report
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(self.output_dir, f"benchmark_report_{timestamp}.json")
        
        # Add metadata to the report
        report = {
            'timestamp': timestamp,
            'config': self.config,
            'results': self.metrics['results']
        }
        
        # Save report as JSON
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Benchmark report saved to {report_file}")
        
        # Generate visualizations
        self.generate_visualizations(timestamp)
        
        return report_file
    
    def generate_visualizations(self, timestamp):
        """Generate visualizations of benchmark results"""
        if not self.metrics.get('results'):
            print("No benchmark results available. Run benchmarks first.")
            return
        
        results = self.metrics['results']
        
        # Create directory for visualizations
        vis_dir = os.path.join(self.output_dir, f"visualizations_{timestamp}")
        os.makedirs(vis_dir, exist_ok=True)
        
        # 1. Bar chart of total processing time by video and model
        plt.figure(figsize=(12, 6))
        
        # Group by video
        videos = sorted(set([r['video_name'] for r in results]))
        models = sorted(set([r['model'] for r in results]))
        
        bar_width = 0.35
        index = range(len(videos))
        
        for i, model in enumerate(models):
            model_results = [r for r in results if r['model'] == model]
            model_results.sort(key=lambda x: videos.index(x['video_name']))
            
            plt.bar(
                [x + i * bar_width for x in index],
                [r['total_time'] for r in model_results],
                bar_width,
                label=model
            )
        
        plt.xlabel('Video')
        plt.ylabel('Processing Time (seconds)')
        plt.title('Total Processing Time by Video and Model')
        plt.xticks([x + bar_width/2 for x in index], videos)
        plt.legend()
        plt.tight_layout()
        plt.savefig(os.path.join(vis_dir, 'total_time_by_video_model.png'))
        plt.close()
        
        # 2. Stacked bar chart of processing stages by video and model
        for model in models:
            plt.figure(figsize=(12, 6))
            
            model_results = [r for r in results if r['model'] == model]
            model_results.sort(key=lambda x: videos.index(x['video_name']))
            
            extraction_times = [r['frame_extraction_time'] for r in model_results]
            sr_times = [r['super_resolution_time'] for r in model_results]
            recomposition_times = [r['video_recomposition_time'] for r in model_results]
            
            plt.bar(videos, extraction_times, label='Frame Extraction')
            plt.bar(videos, sr_times, bottom=extraction_times, label='Super Resolution')
            
            bottoms = [e + s for e, s in zip(extraction_times, sr_times)]
            plt.bar(videos, recomposition_times, bottom=bottoms, label='Video Recomposition')
            
            plt.xlabel('Video')
            plt.ylabel('Processing Time (seconds)')
            plt.title(f'Processing Stages for {model} Model')
            plt.legend()
            plt.tight_layout()
            plt.savefig(os.path.join(vis_dir, f'stages_{model}.png'))
            plt.close()
        
        # 3. Line chart of processing time vs. video duration
        plt.figure(figsize=(12, 6))
        
        for model in models:
            model_results = [r for r in results if r['model'] == model]
            model_results.sort(key=lambda x: x['duration'])
            
            plt.plot(
                [r['duration'] for r in model_results],
                [r['total_time'] for r in model_results],
                'o-',
                label=model
            )
        
        plt.xlabel('Video Duration (seconds)')
        plt.ylabel('Processing Time (seconds)')
        plt.title('Processing Time vs. Video Duration')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plt.savefig(os.path.join(vis_dir, 'time_vs_duration.png'))
        plt.close()
        
        print(f"Visualizations saved to {vis_dir}")

def main():
    """Main function to run benchmarks from command line"""
    parser = argparse.ArgumentParser(description='Benchmark the video super-resolution pipeline')
    parser.add_argument('--config', type=str, help='Path to configuration file')
    parser.add_argument('--output-dir', type=str, help='Directory to save benchmark results')
    args = parser.parse_args()
    
    benchmark = PipelineBenchmark(config_file=args.config, output_dir=args.output_dir)
    benchmark.run_benchmarks()
    benchmark.generate_report()

if __name__ == '__main__':
    main()