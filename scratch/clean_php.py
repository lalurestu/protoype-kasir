import re

def parse_php_file():
    with open('api/index.php', 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the header
    header_match = re.search(r'<\?php.*?try \{.*?\$method = \$_SERVER\[\'REQUEST_METHOD\'\];', content, re.DOTALL)
    if not header_match:
        print("Header not found")
        return
    header = header_match.group(0)

    # Find the footer
    footer_match = re.search(r'    \} else \{.*?http_response_code\(404\);.*$', content, re.DOTALL)
    if not footer_match:
        print("Footer not found")
        return
    footer = footer_match.group(0)

    # Find all if/elseif blocks
    blocks = {}
    
    # Split by "} elseif" and "if ($method"
    # But wait, the first block is `if ($method === ...)`
    
    # A robust regex to find each route block
    pattern = re.compile(r'(?:(?:    \} elseif \()|(?:    if \())(.*?)\) \{(.*?)(?=(?:\n    \} elseif \()|(?:\n    \} else \{)|(?:\n    \/\/ ==================))', re.DOTALL)
    
    matches = pattern.findall(content)
    
    for condition, body in matches:
        # Some blocks might have a trailing "    " or incomplete body due to the corruption
        # E.g. body ending in `$email = <?php`
        if '<?php' in body:
            continue
        
        # Clean up condition
        condition = condition.strip()
        
        # Keep the latest version of each block
        blocks[condition] = body

    # Also extract the custom blocks like `password-reset-requests` that we modified.
    # We can just manually assemble the file.

    out = header + "\n\n"
    
    # Sort blocks or just dump them
    first = True
    for cond, body in blocks.items():
        if first:
            out += f"    if ({cond}) {{" + body
            first = False
        else:
            out += f"\n    }} elseif ({cond}) {{" + body
            
    out += "\n" + footer
    
    with open('api/index_clean.php', 'w', encoding='utf-8') as f:
        f.write(out)
        
    print(f"Cleaned file with {len(blocks)} routes.")

parse_php_file()
