#!/usr/bin/env python3
"""
Video Overlap Calculator for Wan Image-to-Video Generation

This tool helps calculate frame overlaps when stitching multiple Wan video generations
to create longer, smoother videos. Since Wan can generate max 81 frames per generation,
this calculator helps plan segments with proper overlap for seamless transitions.
"""

import argparse
import json
from typing import List, Dict, Tuple

class VideoOverlapCalculator:
    def __init__(self, max_frames: int = 81, overlap_frames: int = 8):
        """
        Initialize the calculator.
        
        Args:
            max_frames: Maximum frames per generation (default: 81 for Wan)
            overlap_frames: Number of frames to overlap between segments
        """
        self.max_frames = max_frames
        self.overlap_frames = overlap_frames
        self.effective_frames = max_frames - overlap_frames
    
    def calculate_segments(self, target_frames: int) -> Dict:
        """
        Calculate how many segments needed and their frame ranges.
        
        Args:
            target_frames: Total desired video length in frames
            
        Returns:
            Dictionary with segment information
        """
        if target_frames <= self.max_frames:
            return {
                'segments_needed': 1,
                'total_generations': 1,
                'target_length': target_frames,
                'calculated_length': target_frames,
                'max_frames_per_gen': self.max_frames,
                'overlap_frames': self.overlap_frames,
                'effective_frames_per_segment': self.effective_frames,
                'segments': [{
                    'segment': 1, 
                    'start_frame': 1, 
                    'end_frame': target_frames, 
                    'generation_frames': target_frames, 
                    'overlap_with_previous': 0, 
                    'skip_frames': 0, 
                    'source_frame': 'Original image', 
                    'note': 'Single generation - no overlap needed'
                }],
                'overlap_info': 'No overlap needed - single generation'
            }
        
        # Calculate segments needed
        remaining_frames = target_frames - self.max_frames
        additional_segments = (remaining_frames + self.effective_frames - 1) // self.effective_frames
        total_segments = 1 + additional_segments
        
        # Calculate actual final length
        final_length = self.max_frames + (additional_segments * self.effective_frames)
        
        # Generate segment details
        segments = []
        current_start = 1
        
        for i in range(total_segments):
            if i == 0:
                # First segment - full generation
                segment = {
                    'segment': i + 1,
                    'start_frame': current_start,
                    'end_frame': current_start + self.max_frames - 1,
                    'generation_frames': self.max_frames,
                    'overlap_with_previous': 0,
                    'skip_frames': 0,  # Start from original image, no skip
                    'source_frame': 'Original image',
                    'note': 'First segment (full generation)'
                }
                current_start += self.effective_frames
            else:
                # Subsequent segments - with overlap
                generation_start_frame = current_start - self.overlap_frames
                skip_frames = generation_start_frame - 1  # Frame to skip to (0-indexed becomes 1-indexed)
                
                generation_end = current_start + self.max_frames - 1
                if i == total_segments - 1:
                    # Adjust last segment if it would exceed target
                    if generation_end > target_frames:
                        generation_frames = target_frames - current_start + self.overlap_frames + 1
                        generation_end = current_start + generation_frames - 1
                    else:
                        generation_frames = self.max_frames
                else:
                    generation_frames = self.max_frames
                
                segment = {
                    'segment': i + 1,
                    'start_frame': current_start,
                    'end_frame': current_start + self.effective_frames - 1,
                    'generation_frames': generation_frames,
                    'generation_start_frame': generation_start_frame,
                    'skip_frames': skip_frames,
                    'source_frame': f'Frame {generation_start_frame}',
                    'overlap_with_previous': self.overlap_frames,
                    'note': f'Overlaps {self.overlap_frames} frames with previous segment'
                }
                current_start += self.effective_frames
            
            segments.append(segment)
        
        return {
            'segments_needed': total_segments,
            'total_generations': total_segments,
            'target_length': target_frames,
            'calculated_length': final_length,
            'max_frames_per_gen': self.max_frames,
            'overlap_frames': self.overlap_frames,
            'effective_frames_per_segment': self.effective_frames,
            'segments': segments
        }
    
    def calculate_from_duration(self, duration_seconds: float, fps: float = 24.0) -> Dict:
        """
        Calculate segments from video duration.
        
        Args:
            duration_seconds: Desired video duration in seconds
            fps: Frames per second (default: 24)
            
        Returns:
            Dictionary with segment information
        """
        target_frames = int(duration_seconds * fps)
        result = self.calculate_segments(target_frames)
        result['duration_seconds'] = duration_seconds
        result['fps'] = fps
        return result
    
    def print_generation_plan(self, segments_info: Dict):
        """Print a detailed generation plan."""
        print("\n" + "="*60)
        print("VIDEO GENERATION PLAN")
        print("="*60)
        
        if 'duration_seconds' in segments_info:
            print(f"Target Duration: {segments_info['duration_seconds']:.1f} seconds @ {segments_info['fps']} FPS")
        
        print(f"Target Frames: {segments_info.get('target_length', segments_info.get('calculated_length'))}")
        print(f"Segments Needed: {segments_info['segments_needed']}")
        print(f"Max Frames per Generation: {segments_info['max_frames_per_gen']}")
        print(f"Overlap Frames: {segments_info['overlap_frames']}")
        print(f"Effective New Frames per Segment: {segments_info['effective_frames_per_segment']}")
        
        if segments_info.get('calculated_length') != segments_info.get('target_length'):
            print(f"Actual Final Length: {segments_info['calculated_length']} frames")
        
        print("\n" + "-"*60)
        print("GENERATION SEQUENCE:")
        print("-"*60)
        
        for segment in segments_info['segments']:
            print(f"\nSegment {segment['segment']}:")
            print(f"  Generate: {segment['generation_frames']} frames")
            print(f"  🎯 Skip frames: {segment['skip_frames']} (start from {segment['source_frame']})")
            
            if segment['segment'] == 1:
                print(f"  Use: Frames 1-{segment['end_frame']} (all frames)")
                print(f"  Source: Original image (no skipping needed)")
            else:
                gen_start = segment.get('generation_start_frame', segment['start_frame'] - self.overlap_frames)
                overlap_frames = segment.get('overlap_with_previous', self.overlap_frames)
                print(f"  Use: Frames {overlap_frames + 1}-{segment['generation_frames']} (skip first {overlap_frames} frames from generation)")
                print(f"  Source: Frame {gen_start} from video timeline")
                print(f"  Overlap: {overlap_frames} frames with previous segment")
            
            print(f"  Final position: Frames {segment['start_frame']}-{segment['end_frame']} in final video")
            if 'note' in segment:
                print(f"  Note: {segment['note']}")
    
    def export_json(self, segments_info: Dict, filename: str):
        """Export the calculation results to JSON file."""
        with open(filename, 'w') as f:
            json.dump(segments_info, f, indent=2)
        print(f"\nGeneration plan exported to: {filename}")

def main():
    parser = argparse.ArgumentParser(description='Calculate video segment overlaps for Wan image-to-video generation')
    parser.add_argument('--frames', type=int, help='Target number of frames')
    parser.add_argument('--duration', type=float, help='Target duration in seconds')
    parser.add_argument('--fps', type=float, default=24.0, help='Frames per second (default: 24)')
    parser.add_argument('--max-frames', type=int, default=81, help='Max frames per generation (default: 81)')
    parser.add_argument('--overlap', type=int, default=8, help='Overlap frames (default: 8)')
    parser.add_argument('--export', type=str, help='Export results to JSON file')
    parser.add_argument('--interactive', action='store_true', help='Run in interactive mode')
    
    args = parser.parse_args()
    
    calculator = VideoOverlapCalculator(max_frames=args.max_frames, overlap_frames=args.overlap)
    
    if args.interactive or (not args.frames and not args.duration):
        # Interactive mode
        print("Wan Video Overlap Calculator")
        print("="*40)
        print(f"Max frames per generation: {args.max_frames}")
        print(f"Overlap frames: {args.overlap}")
        print()
        
        while True:
            try:
                choice = input("Calculate by (f)rames or (d)uration? (q to quit): ").lower()
                if choice == 'q':
                    break
                elif choice == 'f':
                    frames = int(input("Enter target frames: "))
                    result = calculator.calculate_segments(frames)
                elif choice == 'd':
                    duration = float(input("Enter duration in seconds: "))
                    fps = float(input(f"Enter FPS (default {args.fps}): ") or args.fps)
                    result = calculator.calculate_from_duration(duration, fps)
                else:
                    print("Invalid choice. Use 'f' for frames, 'd' for duration, or 'q' to quit.")
                    continue
                
                calculator.print_generation_plan(result)
                
                export_choice = input("\nExport to JSON? (y/n): ").lower()
                if export_choice == 'y':
                    filename = input("Enter filename (default: generation_plan.json): ") or "generation_plan.json"
                    calculator.export_json(result, filename)
                
                print("\n" + "="*60 + "\n")
                
            except (ValueError, KeyboardInterrupt):
                print("\nExiting...")
                break
    else:
        # Command line mode
        if args.frames:
            result = calculator.calculate_segments(args.frames)
        else:
            result = calculator.calculate_from_duration(args.duration, args.fps)
        
        calculator.print_generation_plan(result)
        
        if args.export:
            calculator.export_json(result, args.export)

if __name__ == "__main__":
    main()
