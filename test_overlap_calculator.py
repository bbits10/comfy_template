#!/usr/bin/env python3
"""
Test script for the Video Overlap Calculator
Demonstrates various use cases for Wan video generation planning
"""

from video_overlap_calculator import VideoOverlapCalculator

def test_examples():
    """Test with various common scenarios."""
    
    print("🎬 Wan Video Overlap Calculator - Test Examples")
    print("=" * 60)
    
    calculator = VideoOverlapCalculator(max_frames=81, overlap_frames=8)
    
    # Test cases
    test_cases = [
        {"name": "Short video (single generation)", "frames": 60},
        {"name": "Medium video (2 generations)", "frames": 150},
        {"name": "Long video (4 generations)", "frames": 300},
        {"name": "10-second video at 24fps", "duration": 10, "fps": 24},
        {"name": "30-second video at 30fps", "duration": 30, "fps": 30},
    ]
    
    for i, test in enumerate(test_cases, 1):
        print(f"\n{i}. {test['name']}")
        print("-" * 40)
        
        if 'frames' in test:
            result = calculator.calculate_segments(test['frames'])
        else:
            result = calculator.calculate_from_duration(test['duration'], test['fps'])
        
        # Print summary
        print(f"Target: {result.get('target_length', result.get('calculated_length'))} frames")
        print(f"Segments needed: {result['segments_needed']}")
        print(f"Total generations: {result['total_generations']}")
        
        if result['segments_needed'] > 1:
            print(f"Overlap strategy: {result['overlap_frames']} frames between segments")
            print(f"Effective new frames per segment: {result['effective_frames_per_segment']}")
        
        # Show first two segments as example
        print("\nGeneration sequence:")
        for segment in result['segments'][:2]:  # Show first 2 segments
            if segment['segment'] == 1:
                print(f"  Segment 1: Generate {segment['generation_frames']} frames from original image")
            else:
                print(f"  Segment {segment['segment']}: Generate {segment['generation_frames']} frames starting from frame {segment['generation_start_frame']}")
                print(f"              Use frames {result['overlap_frames'] + 1}-{segment['generation_frames']} (skip first {result['overlap_frames']})")
        
        if len(result['segments']) > 2:
            print(f"  ... and {len(result['segments']) - 2} more segments")

def interactive_mode():
    """Run interactive calculator."""
    
    print("\n🎮 Interactive Mode")
    print("=" * 30)
    
    calculator = VideoOverlapCalculator()
    
    while True:
        try:
            print("\nOptions:")
            print("1. Calculate by target frames")
            print("2. Calculate by duration")
            print("3. Change settings")
            print("4. Exit")
            
            choice = input("\nEnter choice (1-4): ").strip()
            
            if choice == '1':
                frames = int(input("Enter target frames: "))
                result = calculator.calculate_segments(frames)
                calculator.print_generation_plan(result)
                
            elif choice == '2':
                duration = float(input("Enter duration in seconds: "))
                fps = float(input("Enter FPS (default 24): ") or "24")
                result = calculator.calculate_from_duration(duration, fps)
                calculator.print_generation_plan(result)
                
            elif choice == '3':
                max_frames = int(input(f"Max frames per generation (current: {calculator.max_frames}): ") or str(calculator.max_frames))
                overlap = int(input(f"Overlap frames (current: {calculator.overlap_frames}): ") or str(calculator.overlap_frames))
                calculator = VideoOverlapCalculator(max_frames=max_frames, overlap_frames=overlap)
                print(f"Settings updated: Max frames={calculator.max_frames}, Overlap={calculator.overlap_frames}")
                
            elif choice == '4':
                break
                
            else:
                print("Invalid choice. Please enter 1-4.")
                
        except (ValueError, KeyboardInterrupt):
            print("\nExiting...")
            break

if __name__ == "__main__":
    # Run test examples
    test_examples()
    
    # Ask if user wants interactive mode
    print("\n" + "=" * 60)
    try:
        if input("\nRun interactive mode? (y/n): ").lower().startswith('y'):
            interactive_mode()
    except KeyboardInterrupt:
        print("\nGoodbye!")
