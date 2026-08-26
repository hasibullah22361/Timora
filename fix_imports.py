import os
import re

def find_file(filename, search_path):
    for root, dirs, files in os.walk(search_path):
        if filename in files:
            rel_path = os.path.relpath(os.path.join(root, filename), search_path)
            return f"package:timora/{rel_path}"
    return None

def fix_imports():
    os.system("dart analyze --format=machine > machine.log 2>&1")
    
    with open("machine.log", "r") as f:
        lines = f.readlines()
        
    files_to_update = {}
    errors_fixed = 0
    
    for line in lines:
        if "URI_DOES_NOT_EXIST" in line or "uri_does_not_exist" in line:
            parts = line.split("|")
            if len(parts) >= 8:
                severity = parts[0]
                error_code = parts[2]
                file_path = parts[3]
                line_num = int(parts[4])
                col_num = int(parts[5])
                msg = parts[7]
                
                match = re.search(r"Target of URI doesn't exist: '([^']+)'", msg)
                if match:
                    missing_uri = match.group(1)
                    basename = os.path.basename(missing_uri)
                    
                    package_import = find_file(basename, "lib")
                    if package_import:
                        if file_path not in files_to_update:
                            with open(file_path, "r") as f:
                                files_to_update[file_path] = f.readlines()
                        
                        lines_of_file = files_to_update[file_path]
                        line_idx = line_num - 1
                        if line_idx < len(lines_of_file):
                            lines_of_file[line_idx] = re.sub(r"['\"]" + re.escape(missing_uri) + r"['\"]", f"'{package_import}'", lines_of_file[line_idx])
                            errors_fixed += 1
                            
    for fpath, file_lines in files_to_update.items():
        with open(fpath, "w") as f:
            f.writelines(file_lines)
            
    print(f"Fixed {errors_fixed} import errors in {len(files_to_update)} files.")

if __name__ == "__main__":
    fix_imports()
