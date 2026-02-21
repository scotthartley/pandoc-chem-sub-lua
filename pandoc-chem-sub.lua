-- Pandoc Lua filter combining chemical structure formatting and compound name substitution.
-- Chemical structures specified as s:{formula} are converted to subscript/superscript
-- inline elements (e.g. CH3OH, SO4^2-). For LaTeX/beamer output, \ce{} from the
-- mhchem package is emitted instead.
-- Substitution placeholders {name} are replaced with inline elements from the
-- document metadata under the key "substitutions" or "compound names".

-- U+2212 MINUS SIGN used for charge normalisation.
local MINUS_SIGN = "\xe2\x88\x92"

-- Arrow tokens: checked longest-first to avoid prefix shadowing.
local ARROWS = {
    { mhchem = "<=>>", unicode = "\xe2\x87\x92" },   -- U+21D2 ⇒
    { mhchem = "<<=>", unicode = "\xe2\x87\x90" },   -- U+21D0 ⇐
    { mhchem = "<-->", unicode = "\xe2\x9f\xb7" },   -- U+27F7 ⟷
    { mhchem = "<=>",  unicode = "\xe2\x87\x8c" },   -- U+21CC ⇌
    { mhchem = "<->",  unicode = "\xe2\x86\x94" },   -- U+2194 ↔
    { mhchem = "->",   unicode = "\xe2\x86\x92" },   -- U+2192 →
    { mhchem = "<-",   unicode = "\xe2\x86\x90" },   -- U+2190 ←
}

-- States of aggregation recognised inside parentheses.
local STATES = {
    ["aq"] = true, ["aq,sat"] = true, ["s"] = true, ["l"] = true,
    ["g"] = true,  ["cr"] = true,     ["am"] = true, ["vit"] = true,
}

-- ---------------------------------------------------------------------------
-- find_closing_brace(s, open_pos)
-- Returns the position of the '}' that closes the '{' at open_pos, or nil.
-- ---------------------------------------------------------------------------
local function find_closing_brace(s, open_pos)
    local depth = 1
    local i = open_pos + 1
    while i <= #s do
        local c = s:sub(i, i)
        if     c == '{' then depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then return i end
        end
        i = i + 1
    end
    return nil  -- unmatched
end

-- ---------------------------------------------------------------------------
-- parse_group_content(s)
-- Simple renderer for content inside explicit ^{...} or _{...} groups.
-- Each character becomes a Str; ASCII '-' is normalised to U+2212.
-- Digits are NOT subscripted here — they are already in a super/sub context.
-- ---------------------------------------------------------------------------
local function parse_group_content(s)
    local inlines = pandoc.List()
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == '-' then
            inlines:insert(pandoc.Str(MINUS_SIGN))
        elseif c == '.' then
            inlines:insert(pandoc.Str("\xc2\xb7"))  -- U+00B7 MIDDLE DOT (radical dot)
        else
            inlines:insert(pandoc.Str(c))
        end
    end
    return inlines
end

-- ---------------------------------------------------------------------------
-- parse_formula_body(s)
-- Recursive mhchem formula renderer (non-LaTeX path).
-- ---------------------------------------------------------------------------
local function parse_formula_body(s)
    local inlines = pandoc.List()
    local i = 1
    while i <= #s do
        local c = s:sub(i, i)

        if c == '^' then
            local next_c = s:sub(i + 1, i + 1)

            if next_c == '{' then
                -- ^{...} explicit superscript group
                local close = find_closing_brace(s, i + 1)
                if close then
                    local inner = s:sub(i + 2, close - 1)
                    inlines:insert(pandoc.Superscript(parse_group_content(inner)))
                    i = close + 1
                else
                    inlines:insert(pandoc.Str(c))
                    i = i + 1
                end

            elseif next_c == '' then
                -- ^ at end of string → gas-release marker ↑
                inlines:insert(pandoc.Str("\xe2\x86\x91"))
                i = i + 1

            else
                -- ^digits?sign  e.g. ^2- ^+ ^2+
                local charge_str = s:match("^(%d*[%+%-])", i + 1)
                if charge_str then
                    local norm = charge_str:gsub("%-", MINUS_SIGN)
                    inlines:insert(pandoc.Superscript({ pandoc.Str(norm) }))
                    i = i + 1 + #charge_str
                else
                    -- ^ followed by a non-charge character; emit it as superscript
                    inlines:insert(pandoc.Superscript({ pandoc.Str(next_c) }))
                    i = i + 2
                end
            end

        elseif c == '_' then
            local next_c = s:sub(i + 1, i + 1)

            if next_c == '{' then
                -- _{...} explicit subscript group
                local close = find_closing_brace(s, i + 1)
                if close then
                    local inner = s:sub(i + 2, close - 1)
                    inlines:insert(pandoc.Subscript(parse_group_content(inner)))
                    i = close + 1
                else
                    inlines:insert(pandoc.Str(c))
                    i = i + 1
                end

            elseif next_c ~= '' then
                -- _ followed by a single character
                inlines:insert(pandoc.Subscript({ pandoc.Str(next_c) }))
                i = i + 2

            else
                inlines:insert(pandoc.Str(c))
                i = i + 1
            end

        elseif c == '[' then
            -- Find matching ']', track depth
            inlines:insert(pandoc.Str("["))
            local depth = 1
            local j = i + 1
            while j <= #s do
                local cc = s:sub(j, j)
                if     cc == '[' then depth = depth + 1
                elseif cc == ']' then
                    depth = depth - 1
                    if depth == 0 then break end
                end
                j = j + 1
            end
            -- j is at the matching ']' (or past end if unmatched)
            local inner = s:sub(i + 1, j - 1)
            inlines:extend(parse_formula_body(inner))
            inlines:insert(pandoc.Str("]"))
            i = j + 1

        elseif c == '(' then
            -- Look for the closing ')'; check for special sub-cases.
            local close_paren = s:find("%)", i + 1)
            if close_paren then
                local inner = s:sub(i + 1, close_paren - 1)

                if inner == '^' then
                    -- (^) → gas-release marker ↑
                    inlines:insert(pandoc.Str("\xe2\x86\x91"))
                    i = close_paren + 1

                elseif inner == 'v' then
                    -- (v) → precipitate marker ↓
                    inlines:insert(pandoc.Str("\xe2\x86\x93"))
                    i = close_paren + 1

                elseif STATES[inner] then
                    -- State of aggregation: emit upright
                    inlines:insert(pandoc.Str("(" .. inner .. ")"))
                    i = close_paren + 1

                elseif inner:match("^%d+$") then
                    -- Polymer / repeat-unit subscript  e.g. (4)
                    inlines:insert(pandoc.Subscript({ pandoc.Str(inner) }))
                    i = close_paren + 1

                else
                    -- Regular parentheses: recurse on content
                    inlines:insert(pandoc.Str("("))
                    inlines:extend(parse_formula_body(inner))
                    inlines:insert(pandoc.Str(")"))
                    i = close_paren + 1
                end
            else
                -- Unmatched '('
                inlines:insert(pandoc.Str(c))
                i = i + 1
            end

        elseif c:match("%d") then
            -- Digit → Subscript
            inlines:insert(pandoc.Subscript({ pandoc.Str(c) }))
            i = i + 1

        elseif c == '+' then
            -- Trailing charge '+' (reaction-level operator '+' was removed by tokenizer)
            inlines:insert(pandoc.Superscript({ pandoc.Str("+") }))
            i = i + 1

        elseif c == '-' then
            -- Trailing charge '-'; normalise to U+2212
            inlines:insert(pandoc.Superscript({ pandoc.Str(MINUS_SIGN) }))
            i = i + 1

        elseif c == '.' then
            -- Centre dot (mhchem hydrate / bond notation): U+00B7 ·
            -- Digits that immediately follow are a stoichiometric coefficient,
            -- not subscripts, so consume and emit them as plain text.
            inlines:insert(pandoc.Str("\xc2\xb7"))  -- U+00B7 MIDDLE DOT
            local coeff = s:match("^(%d+)", i + 1)
            if coeff then
                inlines:insert(pandoc.Str(coeff))
                i = i + 1 + #coeff
            else
                i = i + 1
            end

        else
            -- Regular character
            inlines:insert(pandoc.Str(c))
            i = i + 1
        end
    end
    return inlines
end

-- ---------------------------------------------------------------------------
-- format_species(s)
-- Extracts a leading numeric coefficient, then delegates to parse_formula_body.
-- ---------------------------------------------------------------------------
local function format_species(s)
    local inlines = pandoc.List()

    -- Leading coefficient: digits with optional decimal/fraction  e.g. 2, 1/2, 2.5
    local coeff, rest = s:match("^(%d+[%.%/]?%d*)([%a%[%^%_%(].*)")
    if not coeff then
        -- Entire string is a bare number (rare but handle it)
        coeff = s:match("^(%d+)$")
        rest  = coeff and "" or nil
    end
    if not coeff then
        rest = s
    end

    if coeff and coeff ~= "" then
        inlines:insert(pandoc.Str(coeff))
        if rest and rest ~= "" then
            inlines:insert(pandoc.Space())
        end
    end

    if rest and rest ~= "" then
        inlines:extend(parse_formula_body(rest))
    end

    return inlines
end

-- ---------------------------------------------------------------------------
-- tokenize_ce(content)
-- Splits a reaction equation into arrow / operator / species tokens.
-- ---------------------------------------------------------------------------
local function tokenize_ce(s)
    local tokens = {}
    local i = 1
    local species_start = 1

    local function flush_species(up_to)
        local text = s:sub(species_start, up_to - 1)
        if text ~= "" then
            table.insert(tokens, { type = "species", content = text })
        end
    end

    while i <= #s do
        local advanced = false

        -- Try arrows (longest first)
        for _, arrow in ipairs(ARROWS) do
            local len = #arrow.mhchem
            if s:sub(i, i + len - 1) == arrow.mhchem then
                flush_species(i)
                table.insert(tokens, { type = "arrow", content = arrow.unicode })
                i = i + len
                species_start = i
                advanced = true
                break
            end
        end

        if not advanced then
            -- Operator '+': only when the character after it starts a new species
            if s:sub(i, i) == '+' then
                local next_c = s:sub(i + 1, i + 1)
                if next_c:match("[%a%d%[%^]") then
                    flush_species(i)
                    table.insert(tokens, { type = "operator", content = "+" })
                    i = i + 1
                    species_start = i
                    advanced = true
                end
            end
        end

        if not advanced then
            i = i + 1
        end
    end

    flush_species(i)  -- flush trailing species
    return tokens
end

-- ---------------------------------------------------------------------------
-- format_ce(content)
-- Top-level formatter for a chem segment (non-LaTeX path).
-- ---------------------------------------------------------------------------
local function format_ce(content)
    local inlines = pandoc.List()
    local tokens  = tokenize_ce(content)

    for _, tok in ipairs(tokens) do
        if tok.type == "arrow" then
            inlines:insert(pandoc.Space())
            inlines:insert(pandoc.Str(tok.content))
            inlines:insert(pandoc.Space())

        elseif tok.type == "operator" then
            inlines:insert(pandoc.Space())
            inlines:insert(pandoc.Str("+"))
            inlines:insert(pandoc.Space())

        elseif tok.type == "species" then
            inlines:extend(format_species(tok.content))
        end
    end

    return inlines
end

-- ---------------------------------------------------------------------------
-- split_string(s)
-- Walk left-to-right, returning typed segments:
--   {type="chem", content=formula}  for s:{...} (nested braces allowed)
--   {type="sub",  content=name}     for {name}
--   {type="text", content=text}     for literal text
-- ---------------------------------------------------------------------------
local function split_string(s)
    local segments = {}
    local pos = 1

    while pos <= #s do
        -- Locate next candidate chem pattern "s:{"
        local chem_marker = s:find("s:%{", pos)

        -- Locate next substitution pattern "{name}" (name has no whitespace/braces)
        local sub_start, sub_end, sub_name = s:find("%{([^%s%}]+)%}", pos)

        -- Validate chem pattern with brace-aware closing search
        local chem_start, chem_end, chem_formula
        if chem_marker then
            local brace_open  = chem_marker + 2  -- position of '{'
            local brace_close = find_closing_brace(s, brace_open)
            if brace_close then
                chem_start   = chem_marker
                chem_end     = brace_close
                chem_formula = s:sub(brace_open + 1, brace_close - 1)
            end
            -- If unmatched, chem_start remains nil
        end

        if not chem_start and not sub_start then
            table.insert(segments, { type = "text", content = s:sub(pos) })
            break
        end

        local next_start, next_end, seg_type, seg_content

        -- Pick whichever starts first; chem wins on a tie
        if chem_start and (not sub_start or chem_start <= sub_start) then
            next_start, next_end = chem_start, chem_end
            seg_type    = "chem"
            seg_content = chem_formula
        else
            next_start, next_end = sub_start, sub_end
            seg_type    = "sub"
            seg_content = sub_name
        end

        -- Emit literal text that precedes the match
        if next_start > pos then
            table.insert(segments, { type = "text", content = s:sub(pos, next_start - 1) })
        end

        table.insert(segments, { type = seg_type, content = seg_content })
        pos = next_end + 1
    end

    return segments
end

-- ---------------------------------------------------------------------------
-- stitch_inlines(ils)
-- Scans an Inlines list for Str elements containing an unclosed s:{.
-- Collects subsequent Str/Space/SoftBreak elements until the opening brace
-- is matched, then replaces the run with a single synthesised Str.
-- Returns the modified list, or nil if no stitching was needed.
-- ---------------------------------------------------------------------------
local function stitch_inlines(ils)
    local result = pandoc.List()
    local i = 1
    local modified = false

    while i <= #ils do
        local el = ils[i]

        if el.tag == "Str" then
            local s = el.text
            local marker_pos = s:find("s:%{")

            if marker_pos then
                local brace_pos = marker_pos + 2   -- position of '{' in s
                local close = find_closing_brace(s, brace_pos)

                if close then
                    -- Fully contained — no stitching needed
                    result:insert(el)
                    i = i + 1
                else
                    -- Opening brace unclosed; collect subsequent tokens
                    local combined = s
                    local j = i + 1
                    local done = false

                    while j <= #ils do
                        local nx = ils[j]
                        if     nx.tag == "Str"       then combined = combined .. nx.text
                        elseif nx.tag == "Space"     then combined = combined .. " "
                        elseif nx.tag == "SoftBreak" then combined = combined .. " "
                        else break
                        end

                        if find_closing_brace(combined, brace_pos) then
                            done = true
                            break
                        end
                        j = j + 1
                    end

                    if done then
                        result:insert(pandoc.Str(combined))
                        modified = true
                        i = j + 1
                    else
                        -- Unmatched brace; emit original token unchanged
                        result:insert(el)
                        i = i + 1
                    end
                end
            else
                result:insert(el)
                i = i + 1
            end
        else
            result:insert(el)
            i = i + 1
        end
    end

    return modified and result or nil
end

-- ---------------------------------------------------------------------------
-- process_str(str_elem, sub_dict)
-- Expand chem and substitution patterns within a Str element.
-- Returns a pandoc.List of Inlines, or nil if no patterns are present.
-- ---------------------------------------------------------------------------
local function process_str(str_elem, sub_dict)
    local s = str_elem.text

    -- Quick exit: neither pattern marker present
    if not s:find("s:%{") and not s:find("%{") then
        return nil
    end

    local segments = split_string(s)

    -- If nothing matched, leave the string alone
    local has_pattern = false
    for _, seg in ipairs(segments) do
        if seg.type == "chem" or seg.type == "sub" then
            has_pattern = true
            break
        end
    end
    if not has_pattern then return nil end

    local result = pandoc.List()

    for _, seg in ipairs(segments) do
        if seg.type == "chem" then
            if FORMAT == "latex" or FORMAT == "beamer" then
                local c = seg.content
                    :gsub("%^$",   " ^")   -- trailing bare ^ → mhchem gas arrow (↑)
                    :gsub("%(^%)", " ^")   -- (^) → mhchem gas arrow (↑)
                result:insert(pandoc.RawInline("latex", "\\ce{" .. c .. "}"))
            else
                result:extend(format_ce((seg.content:gsub("%s+", ""))))
            end

        elseif seg.type == "sub" then
            if sub_dict and sub_dict[seg.content] then
                for _, inline in ipairs(sub_dict[seg.content]) do
                    result:insert(inline)
                end
            else
                -- Unknown name: restore original placeholder
                result:insert(pandoc.Str("{" .. seg.content .. "}"))
            end

        elseif seg.type == "text" and seg.content ~= "" then
            result:insert(pandoc.Str(seg.content))
        end
    end

    return result
end

-- ---------------------------------------------------------------------------
-- get_sub_dict(meta)
-- Return the substitution dictionary from document metadata, or nil.
-- ---------------------------------------------------------------------------
local function get_sub_dict(meta)
    if meta.substitutions then
        return meta.substitutions
    elseif meta["compound names"] then
        return meta["compound names"]
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------
function Pandoc(doc)
    local sub_dict = get_sub_dict(doc.meta)

    -- Pass 1: stitch any multi-token s:{...} spans into single Str elements
    local stitched = doc:walk { Inlines = stitch_inlines }

    -- Pass 2: expand chem and substitution patterns within each Str
    return stitched:walk {
        Str = function(s) return process_str(s, sub_dict) end
    }
end
