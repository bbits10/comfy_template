from flask import Flask, render_template, request, send_file, jsonify, send_from_directory
import os
import zipfile
import tempfile
from pathlib import Path
import mimetypes
from datetime import datetime
import shutil

app = Flask(__name__)

# Base directory for ComfyUI output
OUTPUT_BASE_DIR = "/workspace/ComfyUI/output"

def get_file_info(file_path):
    """Get file information including size, modified date, and type"""
    try:
        stat = os.stat(file_path)
        return {
            'size': stat.st_size,
            'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
            'type': 'file',
            'mime_type': mimetypes.guess_type(file_path)[0] or 'application/octet-stream'
        }
    except:
        return None

def get_folder_contents(folder_path):
    """Get contents of a folder with file information"""
    try:
        items = []
        if not os.path.exists(folder_path):
            os.makedirs(folder_path, exist_ok=True)
        
        for item in os.listdir(folder_path):
            item_path = os.path.join(folder_path, item)
            
            if os.path.isdir(item_path):
                # Count files in directory
                try:
                    file_count = len([f for f in os.listdir(item_path) if os.path.isfile(os.path.join(item_path, f))])
                    items.append({
                        'name': item,
                        'type': 'folder',
                        'file_count': file_count,
                        'modified': datetime.fromtimestamp(os.path.getmtime(item_path)).strftime('%Y-%m-%d %H:%M:%S')
                    })
                except:
                    items.append({
                        'name': item,
                        'type': 'folder',
                        'file_count': 0,
                        'modified': 'Unknown'
                    })
            else:
                file_info = get_file_info(item_path)
                if file_info:
                    items.append({
                        'name': item,
                        **file_info
                    })
        
        # Sort: folders first, then files, alphabetically
        items.sort(key=lambda x: (x['type'] != 'folder', x['name'].lower()))
        return items
    except Exception as e:
        print(f"Error getting folder contents: {e}")
        return []

def format_file_size(size_bytes):
    """Convert bytes to human readable format"""
    if size_bytes == 0:
        return "0 B"
    size_names = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024.0
        i += 1
    return f"{size_bytes:.1f} {size_names[i]}"

@app.route('/')
def index():
    current_path = request.args.get('path', '')
    full_path = os.path.join(OUTPUT_BASE_DIR, current_path.lstrip('/'))
    
    # Security check - ensure we stay within output directory
    if not os.path.abspath(full_path).startswith(os.path.abspath(OUTPUT_BASE_DIR)):
        current_path = ''
        full_path = OUTPUT_BASE_DIR
    
    contents = get_folder_contents(full_path)
    
    # Build breadcrumb navigation
    breadcrumbs = []
    if current_path:
        parts = current_path.strip('/').split('/')
        path_so_far = ''
        for part in parts:
            path_so_far = os.path.join(path_so_far, part).replace('\\', '/')
            breadcrumbs.append({
                'name': part,
                'path': path_so_far
            })
    
    return render_template('file_manager.html', 
                         contents=contents, 
                         current_path=current_path,
                         breadcrumbs=breadcrumbs,
                         format_size=format_file_size)

@app.route('/download')
def download_file():
    file_path = request.args.get('path', '')
    full_path = os.path.join(OUTPUT_BASE_DIR, file_path.lstrip('/'))
    
    # Security check
    if not os.path.abspath(full_path).startswith(os.path.abspath(OUTPUT_BASE_DIR)):
        return "Access denied", 403
    
    if not os.path.exists(full_path) or not os.path.isfile(full_path):
        return "File not found", 404
    
    return send_file(full_path, as_attachment=True)

@app.route('/download_folder')
def download_folder():
    folder_path = request.args.get('path', '')
    full_path = os.path.join(OUTPUT_BASE_DIR, folder_path.lstrip('/'))
    
    # Security check
    if not os.path.abspath(full_path).startswith(os.path.abspath(OUTPUT_BASE_DIR)):
        return "Access denied", 403
    
    if not os.path.exists(full_path) or not os.path.isdir(full_path):
        return "Folder not found", 404
    
    # Create temporary zip file
    temp_dir = tempfile.mkdtemp()
    folder_name = os.path.basename(full_path) or 'output'
    zip_path = os.path.join(temp_dir, f"{folder_name}.zip")
    
    try:
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(full_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, full_path)
                    zipf.write(file_path, arcname)
        
        return send_file(zip_path, as_attachment=True, download_name=f"{folder_name}.zip")
    except Exception as e:
        return f"Error creating zip: {str(e)}", 500
    finally:
        # Clean up temp directory
        try:
            shutil.rmtree(temp_dir)
        except:
            pass

@app.route('/delete', methods=['POST'])
def delete_item():
    item_path = request.json.get('path', '')
    full_path = os.path.join(OUTPUT_BASE_DIR, item_path.lstrip('/'))
    
    # Security check
    if not os.path.abspath(full_path).startswith(os.path.abspath(OUTPUT_BASE_DIR)):
        return jsonify({'error': 'Access denied'}), 403
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Item not found'}), 404
    
    try:
        if os.path.isfile(full_path):
            os.remove(full_path)
        else:
            shutil.rmtree(full_path)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/create_folder', methods=['POST'])
def create_folder():
    current_path = request.json.get('current_path', '')
    folder_name = request.json.get('folder_name', '')
    
    if not folder_name or '/' in folder_name or '\\' in folder_name:
        return jsonify({'error': 'Invalid folder name'}), 400
    
    full_current_path = os.path.join(OUTPUT_BASE_DIR, current_path.lstrip('/'))
    new_folder_path = os.path.join(full_current_path, folder_name)
    
    # Security check
    if not os.path.abspath(new_folder_path).startswith(os.path.abspath(OUTPUT_BASE_DIR)):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        os.makedirs(new_folder_path, exist_ok=False)
        return jsonify({'success': True})
    except FileExistsError:
        return jsonify({'error': 'Folder already exists'}), 409
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/get_storage_info')
def get_storage_info():
    """Get storage information for the output directory"""
    try:
        # Get total size of output directory
        total_size = 0
        file_count = 0
        for dirpath, dirnames, filenames in os.walk(OUTPUT_BASE_DIR):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                try:
                    total_size += os.path.getsize(filepath)
                    file_count += 1
                except:
                    pass
        
        # Get disk usage
        statvfs = os.statvfs(OUTPUT_BASE_DIR)
        disk_total = statvfs.f_frsize * statvfs.f_blocks
        disk_free = statvfs.f_frsize * statvfs.f_bavail
        disk_used = disk_total - disk_free
        
        return jsonify({
            'output_size': total_size,
            'output_size_formatted': format_file_size(total_size),
            'file_count': file_count,
            'disk_total': disk_total,
            'disk_used': disk_used,
            'disk_free': disk_free,
            'disk_total_formatted': format_file_size(disk_total),
            'disk_used_formatted': format_file_size(disk_used),
            'disk_free_formatted': format_file_size(disk_free)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Ensure output directory exists
    os.makedirs(OUTPUT_BASE_DIR, exist_ok=True)
    app.run(host='0.0.0.0', port=8765)
