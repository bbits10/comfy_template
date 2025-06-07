from flask import Flask, render_template, request, send_file, jsonify, send_from_directory, abort
import os
import zipfile
import tempfile
from pathlib import Path
import mimetypes
from datetime import datetime
import shutil
import json
import stat
from urllib.parse import unquote
import subprocess

app = Flask(__name__)

# Base directories - allow broader access but with security
WORKSPACE_DIR = "/workspace"
ALLOWED_DIRECTORIES = [
    "/workspace/ComfyUI/output",
    "/workspace/ComfyUI/input", 
    "/workspace/ComfyUI/models",
    "/workspace/ComfyUI/custom_nodes",
    "/workspace/ComfyUI/temp",
    "/workspace",
    "/tmp"
]

def is_safe_path(path):
    """Check if path is within allowed directories"""
    abs_path = os.path.abspath(path)
    return any(abs_path.startswith(allowed) for allowed in ALLOWED_DIRECTORIES)

def get_file_category(mime_type, file_path):
    """Categorize file for appropriate icon"""
    if not mime_type:
        return 'file'
    
    ext = os.path.splitext(file_path)[1].lower()
    
    if mime_type.startswith('image/'):
        return 'image'
    elif mime_type.startswith('video/'):
        return 'video'
    elif mime_type.startswith('audio/'):
        return 'audio'
    elif mime_type.startswith('text/') or ext in ['.txt', '.md', '.json', '.yaml', '.yml', '.log']:
        return 'text'
    elif ext in ['.pdf']:
        return 'pdf'
    elif ext in ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2']:
        return 'archive'
    elif ext in ['.py', '.js', '.html', '.css', '.cpp', '.c', '.java', '.sh']:
        return 'code'
    elif ext in ['.safetensors', '.ckpt', '.pt', '.pth', '.bin']:
        return 'model'
    else:
        return 'file'

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

def get_file_info(file_path):
    """Get comprehensive file information"""
    try:
        stat_info = os.stat(file_path)
        file_size = stat_info.st_size
        
        # Get MIME type
        mime_type = mimetypes.guess_type(file_path)[0] or 'application/octet-stream'
        
        # File category for icons
        category = get_file_category(mime_type, file_path)
        
        return {
            'size': file_size,
            'size_formatted': format_file_size(file_size),
            'modified': datetime.fromtimestamp(stat_info.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
            'modified_timestamp': stat_info.st_mtime,
            'type': 'file',
            'mime_type': mime_type,
            'category': category,
            'permissions': oct(stat_info.st_mode)[-3:],
            'is_readable': os.access(file_path, os.R_OK),
            'is_writable': os.access(file_path, os.W_OK),
            'extension': os.path.splitext(file_path)[1].lower()
        }
    except Exception as e:
        return None

def get_directory_size(directory):
    """Calculate total size of directory (with limit for performance)"""
    total_size = 0
    file_count = 0
    try:
        for dirpath, dirnames, filenames in os.walk(directory):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                try:
                    total_size += os.path.getsize(filepath)
                    file_count += 1
                    # Limit for performance - stop counting after 1000 files
                    if file_count > 1000:
                        return total_size, file_count, True
                except:
                    pass
    except:
        pass
    return total_size, file_count, False

def get_folder_contents(folder_path, sort_by='name', sort_order='asc'):
    """Get contents of a folder with comprehensive information"""
    try:
        items = []
        if not os.path.exists(folder_path):
            return items
        
        for item in os.listdir(folder_path):
            item_path = os.path.join(folder_path, item)
            
            try:
                stat_info = os.stat(item_path)
                
                if os.path.isdir(item_path):
                    # Count files and subdirectories
                    try:
                        contents = os.listdir(item_path)
                        file_count = len([f for f in contents if os.path.isfile(os.path.join(item_path, f))])
                        dir_count = len([f for f in contents if os.path.isdir(os.path.join(item_path, f))])
                        total_size, _, is_truncated = get_directory_size(item_path)
                    except:
                        file_count = dir_count = 0
                        total_size = 0
                        is_truncated = False
                    
                    items.append({
                        'name': item,
                        'type': 'folder',
                        'file_count': file_count,
                        'dir_count': dir_count,
                        'size': total_size,
                        'size_formatted': format_file_size(total_size) + (' (est.)' if is_truncated else ''),
                        'modified': datetime.fromtimestamp(stat_info.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
                        'modified_timestamp': stat_info.st_mtime,
                        'permissions': oct(stat_info.st_mode)[-3:],
                        'is_readable': os.access(item_path, os.R_OK),
                        'is_writable': os.access(item_path, os.W_OK)
                    })
                else:
                    # File
                    file_info = get_file_info(item_path)
                    if file_info:
                        file_info['name'] = item
                        items.append(file_info)
            except Exception as e:
                continue
        
        # Sort items
        if sort_by == 'name':
            items.sort(key=lambda x: x['name'].lower(), reverse=(sort_order == 'desc'))
        elif sort_by == 'size':
            items.sort(key=lambda x: x.get('size', 0), reverse=(sort_order == 'desc'))
        elif sort_by == 'modified':
            items.sort(key=lambda x: x.get('modified_timestamp', 0), reverse=(sort_order == 'desc'))
        elif sort_by == 'type':
            items.sort(key=lambda x: (x['type'], x['name'].lower()), reverse=(sort_order == 'desc'))
        
        # Separate folders and files, folders first unless sorted by other criteria
        if sort_by == 'name' or sort_by == 'type':
            folders = [item for item in items if item['type'] == 'folder']
            files = [item for item in items if item['type'] == 'file']
            return folders + files
        else:
            return items
        
    except Exception as e:
        return []

def get_breadcrumbs(path):
    """Generate breadcrumb navigation"""
    parts = [p for p in path.split('/') if p]
    breadcrumbs = [{'name': 'workspace', 'path': '/workspace'}]
    
    current_path = '/workspace'
    for part in parts[1:]:  # Skip 'workspace' as it's already added
        current_path += '/' + part
        if is_safe_path(current_path):
            breadcrumbs.append({'name': part, 'path': current_path})
    
    return breadcrumbs

@app.route('/')
def index():
    """Main file manager interface"""
    current_path = request.args.get('path', '/workspace/ComfyUI/output')
    
    # Security check
    if not is_safe_path(current_path):
        current_path = '/workspace/ComfyUI/output'
    
    # Ensure path exists
    if not os.path.exists(current_path):
        try:
            os.makedirs(current_path, exist_ok=True)
        except:
            current_path = '/workspace'
    
    return render_template('file_manager.html', current_path=current_path)

@app.route('/api/browse')
def browse():
    """API endpoint to browse directory contents"""
    path = request.args.get('path', '/workspace/ComfyUI/output')
    sort_by = request.args.get('sort', 'name')
    sort_order = request.args.get('order', 'asc')
    
    # Security check
    if not is_safe_path(path):
        return jsonify({'error': 'Access denied to this directory'}), 403
    
    if not os.path.exists(path):
        return jsonify({'error': 'Directory does not exist'}), 404
    
    try:
        contents = get_folder_contents(path, sort_by, sort_order)
        
        # Get parent directory
        parent_path = os.path.dirname(path) if path != '/workspace' else None
        if parent_path and not is_safe_path(parent_path):
            parent_path = None
        
        # Get breadcrumb path
        breadcrumbs = get_breadcrumbs(path)
        
        return jsonify({
            'current_path': path,
            'parent_path': parent_path,
            'contents': contents,
            'breadcrumbs': breadcrumbs,
            'total_items': len(contents),
            'total_files': len([item for item in contents if item['type'] == 'file']),
            'total_folders': len([item for item in contents if item['type'] == 'folder'])
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/download')
def download_file():
    """Download a single file"""
    file_path = request.args.get('path', '')
    
    # Security check
    if not is_safe_path(file_path):
        return jsonify({'error': 'Access denied'}), 403
    
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        return jsonify({'error': 'File not found'}), 404
    
    return send_file(file_path, as_attachment=True)

@app.route('/api/download_multiple', methods=['POST'])
def download_multiple():
    """Download multiple files as a zip"""
    files = request.json.get('files', [])
    
    if not files:
        return jsonify({'error': 'No files specified'}), 400
    
    # Security check for all files
    for file_path in files:
        if not is_safe_path(file_path):
            return jsonify({'error': f'Access denied to {file_path}'}), 403
        if not os.path.exists(file_path):
            return jsonify({'error': f'File not found: {file_path}'}), 404
    
    # Create temporary zip file
    temp_dir = tempfile.mkdtemp()
    zip_path = os.path.join(temp_dir, 'selected_files.zip')
    
    try:
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for file_path in files:
                if os.path.isfile(file_path):
                    # Use just the filename for files
                    arcname = os.path.basename(file_path)
                    zipf.write(file_path, arcname)
                elif os.path.isdir(file_path):
                    # For directories, preserve structure
                    folder_name = os.path.basename(file_path)
                    for root, dirs, files_in_dir in os.walk(file_path):
                        for file in files_in_dir:
                            file_full_path = os.path.join(root, file)
                            arcname = os.path.join(folder_name, os.path.relpath(file_full_path, file_path))
                            zipf.write(file_full_path, arcname)
        
        return send_file(zip_path, as_attachment=True, download_name='selected_files.zip')
    except Exception as e:
        return jsonify({'error': f'Error creating zip: {str(e)}'}), 500
    finally:
        # Clean up will happen after send_file completes
        pass

@app.route('/api/download_folder')
def download_folder():
    """Download entire folder as zip"""
    folder_path = request.args.get('path', '')
    
    # Security check
    if not is_safe_path(folder_path):
        return jsonify({'error': 'Access denied'}), 403
    
    if not os.path.exists(folder_path) or not os.path.isdir(folder_path):
        return jsonify({'error': 'Folder not found'}), 404
    
    # Create temporary zip file
    temp_dir = tempfile.mkdtemp()
    folder_name = os.path.basename(folder_path) or 'files'
    zip_path = os.path.join(temp_dir, f"{folder_name}.zip")
    
    try:
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(folder_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, folder_path)
                    zipf.write(file_path, arcname)
        
        return send_file(zip_path, as_attachment=True, download_name=f"{folder_name}.zip")
    except Exception as e:
        return jsonify({'error': f'Error creating zip: {str(e)}'}), 500

@app.route('/api/delete', methods=['POST'])
def delete_items():
    """Delete one or more files/folders"""
    items = request.json.get('items', [])
    
    if not items:
        return jsonify({'error': 'No items specified'}), 400
    
    deleted = []
    errors = []
    
    for item_path in items:
        # Security check
        if not is_safe_path(item_path):
            errors.append(f'Access denied: {item_path}')
            continue
        
        if not os.path.exists(item_path):
            errors.append(f'Not found: {item_path}')
            continue
        
        try:
            if os.path.isfile(item_path):
                os.remove(item_path)
                deleted.append(item_path)
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path)
                deleted.append(item_path)
        except Exception as e:
            errors.append(f'Error deleting {item_path}: {str(e)}')
    
    return jsonify({
        'deleted': deleted,
        'errors': errors,
        'success': len(errors) == 0
    })

@app.route('/api/create_folder', methods=['POST'])
def create_folder():
    """Create a new folder"""
    current_path = request.json.get('current_path', '')
    folder_name = request.json.get('folder_name', '')
    
    if not folder_name or '/' in folder_name or '\\' in folder_name or folder_name in ['.', '..']:
        return jsonify({'error': 'Invalid folder name'}), 400
    
    new_folder_path = os.path.join(current_path, folder_name)
    
    # Security check
    if not is_safe_path(new_folder_path):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        os.makedirs(new_folder_path, exist_ok=False)
        return jsonify({'success': True, 'path': new_folder_path})
    except FileExistsError:
        return jsonify({'error': 'Folder already exists'}), 409
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/rename', methods=['POST'])
def rename_item():
    """Rename a file or folder"""
    old_path = request.json.get('old_path', '')
    new_name = request.json.get('new_name', '')
    
    if not new_name or '/' in new_name or '\\' in new_name or new_name in ['.', '..']:
        return jsonify({'error': 'Invalid name'}), 400
    
    # Security check
    if not is_safe_path(old_path):
        return jsonify({'error': 'Access denied'}), 403
    
    if not os.path.exists(old_path):
        return jsonify({'error': 'Item not found'}), 404
    
    new_path = os.path.join(os.path.dirname(old_path), new_name)
    
    # Security check for new path
    if not is_safe_path(new_path):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        os.rename(old_path, new_path)
        return jsonify({'success': True, 'new_path': new_path})
    except FileExistsError:
        return jsonify({'error': 'Name already exists'}), 409
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """Upload files to current directory"""
    current_path = request.form.get('current_path', '')
    
    # Security check
    if not is_safe_path(current_path):
        return jsonify({'error': 'Access denied'}), 403
    
    if 'files' not in request.files:
        return jsonify({'error': 'No files provided'}), 400
    
    files = request.files.getlist('files')
    uploaded = []
    errors = []
    
    for file in files:
        if file.filename == '':
            continue
        
        try:
            filename = file.filename
            file_path = os.path.join(current_path, filename)
            
            # Security check for file path
            if not is_safe_path(file_path):
                errors.append(f'Access denied: {filename}')
                continue
            
            file.save(file_path)
            uploaded.append(filename)
        except Exception as e:
            errors.append(f'Error uploading {file.filename}: {str(e)}')
    
    return jsonify({
        'uploaded': uploaded,
        'errors': errors,
        'success': len(errors) == 0
    })

@app.route('/api/storage_info')
def get_storage_info():
    """Get storage information"""
    path = request.args.get('path', '/workspace')
    
    # Security check
    if not is_safe_path(path):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        # Get directory size
        total_size, file_count, is_truncated = get_directory_size(path)
        
        # Get disk usage
        statvfs = os.statvfs(path)
        disk_total = statvfs.f_frsize * statvfs.f_blocks
        disk_free = statvfs.f_frsize * statvfs.f_bavail
        disk_used = disk_total - disk_free
        
        return jsonify({
            'directory_size': total_size,
            'directory_size_formatted': format_file_size(total_size),
            'file_count': file_count,
            'size_truncated': is_truncated,
            'disk_total': disk_total,
            'disk_used': disk_used,
            'disk_free': disk_free,
            'disk_total_formatted': format_file_size(disk_total),
            'disk_used_formatted': format_file_size(disk_used),
            'disk_free_formatted': format_file_size(disk_free),
            'disk_usage_percent': round((disk_used / disk_total) * 100, 1)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/search')
def search_files():
    """Search for files and folders"""
    query = request.args.get('q', '').strip()
    path = request.args.get('path', '/workspace/ComfyUI/output')
    
    if not query or len(query) < 2:
        return jsonify({'error': 'Search query too short'}), 400
    
    # Security check
    if not is_safe_path(path):
        return jsonify({'error': 'Access denied'}), 403
    
    try:
        results = []
        query_lower = query.lower()
        
        for root, dirs, files in os.walk(path):
            # Skip if we can't access the directory
            if not is_safe_path(root):
                continue
                
            # Search in directory names
            for dir_name in dirs:
                if query_lower in dir_name.lower():
                    dir_path = os.path.join(root, dir_name)
                    relative_path = os.path.relpath(dir_path, path)
                    results.append({
                        'name': dir_name,
                        'path': dir_path,
                        'relative_path': relative_path,
                        'type': 'folder'
                    })
            
            # Search in file names
            for file_name in files:
                if query_lower in file_name.lower():
                    file_path = os.path.join(root, file_name)
                    relative_path = os.path.relpath(file_path, path)
                    file_info = get_file_info(file_path)
                    if file_info:
                        results.append({
                            'name': file_name,
                            'path': file_path,
                            'relative_path': relative_path,
                            'type': 'file',
                            'size_formatted': file_info['size_formatted'],
                            'category': file_info['category']
                        })
            
            # Limit results for performance
            if len(results) > 100:
                break
        
        return jsonify({
            'results': results,
            'total': len(results),
            'truncated': len(results) >= 100
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8765, debug=False)
