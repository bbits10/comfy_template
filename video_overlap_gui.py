#!/usr/bin/env python3
"""
GUI Video Overlap Calculator for Wan Image-to-Video Generation

A simple tkinter-based GUI for calculating video segment overlaps.
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, filedialog, messagebox
import json
from video_overlap_calculator import VideoOverlapCalculator

class VideoOverlapGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Wan Video Overlap Calculator")
        self.root.geometry("800x700")
        
        # Calculator instance
        self.calculator = VideoOverlapCalculator()
        
        self.setup_ui()
    
    def setup_ui(self):
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="Wan Video Overlap Calculator", 
                               font=('Arial', 16, 'bold'))
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))
        
        # Settings frame
        settings_frame = ttk.LabelFrame(main_frame, text="Settings", padding="5")
        settings_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        settings_frame.columnconfigure(1, weight=1)
        
        ttk.Label(settings_frame, text="Max Frames per Generation:").grid(row=0, column=0, sticky=tk.W, padx=(0, 5))
        self.max_frames_var = tk.StringVar(value="81")
        max_frames_entry = ttk.Entry(settings_frame, textvariable=self.max_frames_var, width=10)
        max_frames_entry.grid(row=0, column=1, sticky=tk.W)
        
        ttk.Label(settings_frame, text="Overlap Frames:").grid(row=0, column=2, sticky=tk.W, padx=(20, 5))
        self.overlap_var = tk.StringVar(value="8")
        overlap_entry = ttk.Entry(settings_frame, textvariable=self.overlap_var, width=10)
        overlap_entry.grid(row=0, column=3, sticky=tk.W)
        
        # Input frame
        input_frame = ttk.LabelFrame(main_frame, text="Target Video", padding="5")
        input_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        input_frame.columnconfigure(1, weight=1)
        
        # Calculation method
        self.calc_method = tk.StringVar(value="frames")
        ttk.Radiobutton(input_frame, text="By Frames", variable=self.calc_method, 
                       value="frames", command=self.toggle_input_method).grid(row=0, column=0, sticky=tk.W)
        ttk.Radiobutton(input_frame, text="By Duration", variable=self.calc_method, 
                       value="duration", command=self.toggle_input_method).grid(row=0, column=1, sticky=tk.W)
        
        # Frames input
        self.frames_frame = ttk.Frame(input_frame)
        self.frames_frame.grid(row=1, column=0, columnspan=4, sticky=(tk.W, tk.E), pady=5)
        ttk.Label(self.frames_frame, text="Target Frames:").grid(row=0, column=0, sticky=tk.W, padx=(0, 5))
        self.target_frames_var = tk.StringVar()
        frames_entry = ttk.Entry(self.frames_frame, textvariable=self.target_frames_var, width=15)
        frames_entry.grid(row=0, column=1, sticky=tk.W)
        
        # Duration input
        self.duration_frame = ttk.Frame(input_frame)
        self.duration_frame.grid(row=2, column=0, columnspan=4, sticky=(tk.W, tk.E), pady=5)
        ttk.Label(self.duration_frame, text="Duration (seconds):").grid(row=0, column=0, sticky=tk.W, padx=(0, 5))
        self.duration_var = tk.StringVar()
        duration_entry = ttk.Entry(self.duration_frame, textvariable=self.duration_var, width=15)
        duration_entry.grid(row=0, column=1, sticky=tk.W)
        
        ttk.Label(self.duration_frame, text="FPS:").grid(row=0, column=2, sticky=tk.W, padx=(20, 5))
        self.fps_var = tk.StringVar(value="24")
        fps_entry = ttk.Entry(self.duration_frame, textvariable=self.fps_var, width=10)
        fps_entry.grid(row=0, column=3, sticky=tk.W)
        
        # Initially hide duration frame
        self.toggle_input_method()
        
        # Calculate button
        calc_button = ttk.Button(main_frame, text="Calculate", command=self.calculate)
        calc_button.grid(row=3, column=0, columnspan=3, pady=10)
        
        # Results frame
        results_frame = ttk.LabelFrame(main_frame, text="Generation Plan", padding="5")
        results_frame.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        results_frame.columnconfigure(0, weight=1)
        results_frame.rowconfigure(0, weight=1)
        main_frame.rowconfigure(4, weight=1)
        
        self.results_text = scrolledtext.ScrolledText(results_frame, wrap=tk.WORD, width=80, height=20)
        self.results_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Export button
        export_button = ttk.Button(main_frame, text="Export to JSON", command=self.export_json)
        export_button.grid(row=5, column=0, columnspan=3, pady=5)
        
        # Store last calculation result
        self.last_result = None
    
    def toggle_input_method(self):
        """Toggle between frames and duration input methods."""
        if self.calc_method.get() == "frames":
            self.frames_frame.grid()
            self.duration_frame.grid_remove()
        else:
            self.frames_frame.grid_remove()
            self.duration_frame.grid()
    
    def calculate(self):
        """Perform the calculation and display results."""
        try:
            # Update calculator settings
            max_frames = int(self.max_frames_var.get())
            overlap = int(self.overlap_var.get())
            self.calculator = VideoOverlapCalculator(max_frames=max_frames, overlap_frames=overlap)
            
            # Get calculation parameters
            if self.calc_method.get() == "frames":
                target_frames = int(self.target_frames_var.get())
                result = self.calculator.calculate_segments(target_frames)
            else:
                duration = float(self.duration_var.get())
                fps = float(self.fps_var.get())
                result = self.calculator.calculate_from_duration(duration, fps)
            
            # Store result
            self.last_result = result
            
            # Display results
            self.display_results(result)
            
        except ValueError as e:
            messagebox.showerror("Input Error", "Please enter valid numbers for all fields.")
        except Exception as e:
            messagebox.showerror("Calculation Error", f"An error occurred: {str(e)}")
    
    def display_results(self, result):
        """Display calculation results in the text area."""
        self.results_text.delete(1.0, tk.END)
        
        output = []
        output.append("=" * 60)
        output.append("VIDEO GENERATION PLAN")
        output.append("=" * 60)
        
        if 'duration_seconds' in result:
            output.append(f"Target Duration: {result['duration_seconds']:.1f} seconds @ {result['fps']} FPS")
        
        output.append(f"Target Frames: {result.get('target_length', result.get('calculated_length'))}")
        output.append(f"Segments Needed: {result['segments_needed']}")
        output.append(f"Max Frames per Generation: {result['max_frames_per_gen']}")
        output.append(f"Overlap Frames: {result['overlap_frames']}")
        output.append(f"Effective New Frames per Segment: {result['effective_frames_per_segment']}")
        
        if result.get('calculated_length') != result.get('target_length'):
            output.append(f"Actual Final Length: {result['calculated_length']} frames")
        
        output.append("")
        output.append("-" * 60)
        output.append("GENERATION SEQUENCE:")
        output.append("-" * 60)
        
        for segment in result['segments']:
            output.append(f"\nSegment {segment['segment']}:")
            output.append(f"  Generate: {segment['generation_frames']} frames")
            
            if segment['segment'] == 1:
                output.append(f"  Use: Frames 1-{segment['end_frame']} (all frames)")
                output.append(f"  Source: Original image")
            else:
                gen_start = segment.get('generation_start_frame', segment['start_frame'] - result['overlap_frames'])
                output.append(f"  Use: Frames {result['overlap_frames'] + 1}-{segment['generation_frames']} (skip first {result['overlap_frames']} frames)")
                output.append(f"  Source: Frame {gen_start} from video timeline")
                output.append(f"  Overlap: {segment['overlap_frames']} frames with previous segment")
            
            output.append(f"  Final position: Frames {segment['start_frame']}-{segment['end_frame']} in final video")
            if 'note' in segment:
                output.append(f"  Note: {segment['note']}")
        
        self.results_text.insert(tk.END, "\n".join(output))
    
    def export_json(self):
        """Export the last calculation result to a JSON file."""
        if not self.last_result:
            messagebox.showwarning("No Data", "Please calculate first before exporting.")
            return
        
        filename = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")],
            title="Save Generation Plan"
        )
        
        if filename:
            try:
                with open(filename, 'w') as f:
                    json.dump(self.last_result, f, indent=2)
                messagebox.showinfo("Export Successful", f"Generation plan exported to:\n{filename}")
            except Exception as e:
                messagebox.showerror("Export Error", f"Failed to export file:\n{str(e)}")

def main():
    root = tk.Tk()
    app = VideoOverlapGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()
