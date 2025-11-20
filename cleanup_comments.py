#!/usr/bin/env python3
"""
Script to clean up Claude Code related comments from flexible-pipeline files
"""

import os
import re

def clean_file(filepath):
    """Clean Claude Code comments from a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Patterns to match Claude Code related comments
        patterns = [
            r'//.*\*\*ULTRA.*THINK.*\*\*.*',
            r'//.*\*\*STATE.*ART.*\*\*.*',
            r'//.*\*\*ACADEMIC.*DEBUG.*\*\*.*',
            r'//.*\*\*DEBUG.*ACADEMIC.*\*\*.*',
            r'//.*\*\*.*FIXED.*\*\*.*',
            r'//.*\*\*.*ENHANCED.*\*\*.*',
            r'//.*\*\*.*SIMPLIFIED.*\*\*.*',
            r'//.*\*\*.*VALIDATION.*\*\*.*',
            r'//.*\*\*.*RECORDING.*\*\*.*',
            r'//.*\*\*.*REMOVED.*\*\*.*',
            r'//.*\*\*.*TIMING.*\*\*.*',
            r'//.*Ultra Think.*',
            r'//.*ultra think.*',
            r'//.*State-of-the-art.*',
            r'//.*state-of-the-art.*',
            # Additional patterns for multi-line comments
            r'/\*.*\*\*ULTRA.*THINK.*\*\*.*\*/',
            r'/\*.*\*\*SIMPLIFIED\*\*.*\*/',
            r'/\*.*Ultra Think.*\*/',
            # Header comment patterns
            r'.*\*\*SIMPLIFIED\*\*.*',
            r'.*Ultra Think.*',
        ]
        
        # Remove matching patterns
        modified = False
        for pattern in patterns:
            old_content = content
            content = re.sub(pattern, '', content, flags=re.IGNORECASE)
            if content != old_content:
                modified = True
        
        # Clean up debug printf statements with ACADEMIC, ULTRA, etc.
        printf_patterns = [
            r'printf\(".*ACADEMIC.*".*\);',
            r'printf\(".*ULTRA.*".*\);',
            r'printf\(".*DEBUG.*".*\);',
            r'printf\(".*MVPP.*".*\);',
            r'printf\(".*PSO.*".*\);',
            r'printf\(".*STATE.*ART.*".*\);',
        ]
        
        for pattern in printf_patterns:
            old_content = content
            content = re.sub(pattern, '', content, flags=re.IGNORECASE | re.MULTILINE)
            if content != old_content:
                modified = True
        
        # Clean up empty lines left by removed comments
        content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Cleaned: {filepath}")
            return True
        else:
            print(f"No changes needed: {filepath}")
            return False
            
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to clean all files in flexible-pipeline directory"""
    base_dir = "/home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline"
    
    # File extensions to process
    extensions = ['.cc', '.hh', '.cpp', '.hpp', '.c', '.h']
    
    # Skip backup files and markdown files
    skip_files = ['Router.cc.backup_sensitivity', 'MVPP_MGC_PSO_Performance_Metrics_Reference.md']
    
    files_processed = 0
    files_modified = 0
    
    for filename in os.listdir(base_dir):
        filepath = os.path.join(base_dir, filename)
        
        # Skip directories and non-source files
        if not os.path.isfile(filepath):
            continue
            
        # Skip unwanted files
        if filename in skip_files:
            continue
            
        # Only process source files
        if not any(filename.endswith(ext) for ext in extensions):
            continue
            
        files_processed += 1
        if clean_file(filepath):
            files_modified += 1
    
    print(f"\nSummary:")
    print(f"Files processed: {files_processed}")
    print(f"Files modified: {files_modified}")

if __name__ == "__main__":
    main()