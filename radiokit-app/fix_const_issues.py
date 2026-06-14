#!/usr/bin/env python3
"""
Fix 'const' widget constructors that have 'context.tokens' as arguments.
These cause 'Invalid constant value' errors because context.tokens is not a compile-time constant.
Removes the 'const' keyword from such constructors.
"""

import os
import re

PROJECT = "lib"

def fix_file(filepath):
    """Remove const from widget constructors that contain context.tokens."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    if 'context.tokens' not in content:
        return False
    
    original = content
    
    # Strategy: find 'const WidgetName(' patterns, track bracket nesting,
    # and if context.tokens appears before the closing bracket, remove const.
    
    result = []
    i = 0
    while i < len(content):
        # Look for 'const ' followed by word and '('
        m = re.search(r'\bconst\s+([A-Za-z_]\w*)\s*\(', content[i:])
        if not m:
            result.append(content[i:])
            break
        
        start = i + m.start()
        const_end = i + m.end()  # position right after '('
        
        # Now scan for matching closing paren, tracking nesting
        depth = 1
        j = const_end
        in_string = False
        string_char = None
        
        while j < len(content) and depth > 0:
            ch = content[j]
            
            # Handle string literals
            if not in_string:
                if ch in ('"', "'"):
                    in_string = True
                    string_char = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            else:
                if ch == '\\':
                    j += 1  # skip escaped char
                elif ch == string_char:
                    in_string = False
            j += 1
        
        # Check if context.tokens appears between ( and matching )
        segment = content[const_end:j-1]  # everything inside parens
        has_tokens = 'context.tokens' in segment
        
        if has_tokens:
            # Remove 'const ' - keep everything else
            result.append(content[i:start])
            # Skip 'const ' (7 chars) and append the rest
            result.append(content[start + 6:j])
        else:
            result.append(content[i:j])
        
        i = j
    
    new_content = ''.join(result)
    if new_content != original:
        with open(filepath, 'w') as f:
            f.write(new_content)
        return True
    return False

def main():
    count = 0
    for root, dirs, files in os.walk(PROJECT):
        for f in files:
            if f.endswith('.dart'):
                path = os.path.join(root, f)
                if fix_file(path):
                    count += 1
                    print(f"Fixed: {path}")
    
    print(f"\nFixed {count} files")

if __name__ == '__main__':
    main()
