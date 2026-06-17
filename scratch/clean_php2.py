import re

def parse_php_file():
    with open('api/index.php', 'r', encoding='utf-8') as f:
        content = f.read()

    header_match = re.search(r'<\?php.*?try \{.*?\$method = \$_SERVER\[\'REQUEST_METHOD\'\];', content, re.DOTALL)
    header = header_match.group(0)

    footer_match = re.search(r'    \} else \{.*?http_response_code\(404\);.*$', content, re.DOTALL)
    footer = footer_match.group(0)

    # Use a regex that matches until the next '} elseif (' or '} else {'
    pattern = re.compile(r'(?:    \} elseif \((.*?)\) \{|    if \((.*?)\) \{)(.*?)(?=\n    \} elseif \(|\n    \} else \{|\n    // ========)', re.DOTALL)
    
    matches = pattern.findall(content)
    
    blocks = {}
    for m in matches:
        condition = m[0] if m[0] else m[1]
        body = m[2]
        
        # Skip severely corrupted blocks (like those containing <?php)
        if '<?php' in body:
            continue
            
        # Ensure the body ends with a newline and properly closes braces if needed.
        # But wait, the regex assumes the body DOES NOT include the closing brace of the route block itself.
        # Actually, the regex matches everything up to the NEXT `} elseif`.
        # This means the current block's closing brace is actually the `}` of the NEXT `} elseif`!
        # This is a common parsing error with string splitting.
        
        blocks[condition.strip()] = body

    out = header + "\n\n"
    
    first = True
    for cond, body in blocks.items():
        # The body string contains everything inside the block, but NOT the closing brace.
        # Wait, if the condition is `if (...) {`, then the closing `}` is part of the `} elseif`!
        if first:
            out += f"    if ({cond}) {{" + body
            first = False
        else:
            out += f"\n    }} elseif ({cond}) {{" + body
            
    # The last block doesn't have a closing brace because `footer` starts with `    } else {`
    # So `footer` provides the closing brace for the last `elseif`!
    out += "\n" + footer
    
    with open('api/index_clean2.php', 'w', encoding='utf-8') as f:
        f.write(out)

parse_php_file()
