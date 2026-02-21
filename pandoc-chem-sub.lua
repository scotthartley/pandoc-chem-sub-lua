-- Pandoc Lua filter combining chemical structure formatting and compound name substitution.
-- Chemical structures specified as s:{formula} are converted to subscript/superscript
-- inline elements (e.g. CH3OH, SO4^2-). For LaTeX/beamer output, \ce{} from the
-- mhchem package is emitted instead.
-- Substitution placeholders {name} are replaced with inline elements from the
-- document metadata under the key "substitutions" or "compound names".

-- UTF-8 encodings for Unicode minus signs.
-- U+2212 MINUS SIGN and U+2013 EN DASH are treated as charge indicators.
local MINUS_SIGN = "\xe2\x88\x92"  -- U+2212
local EN_DASH    = "\xe2\x80\x93"  -- U+2013

-- Split a chemical formula string into (formula, charge).
-- Returns (formula, charge) if a trailing charge is found, or (s, nil) otherwise.
-- ASCII hyphens in the charge are replaced with U+2212 MINUS SIGN.
local function split_charge(s)
    local formula, charge

    -- Case 1: explicit ^ separator with ASCII charge, e.g. SO4^2-
    formula, charge = s:match("^([%w]+)%^(%d*[%-+])$")

    -- Case 1b: explicit ^ separator with UTF-8 minus sign
    if not formula then
        formula, charge = s:match("^([%w]+)%^(%d*" .. MINUS_SIGN .. ")$")
    end

    -- Case 1c: explicit ^ separator with en dash
    if not formula then
        formula, charge = s:match("^([%w]+)%^(%d*" .. EN_DASH .. ")$")
    end

    -- Case 2: implicit trailing ASCII charge, e.g. CH3O- or Na+
    if not formula then
        formula, charge = s:match("^([%w]+)(%d*[%-+])$")
    end

    -- Case 2b: implicit trailing UTF-8 minus sign (3 bytes at end of string)
    if not formula then
        if s:sub(-3) == MINUS_SIGN then
            local prefix = s:sub(1, -4)
            local num = prefix:match("(%d+)$")
            if num then
                formula = prefix:sub(1, -(#num + 1))
                charge  = num .. MINUS_SIGN
            else
                formula = prefix
                charge  = MINUS_SIGN
            end
        elseif s:sub(-3) == EN_DASH then
            local prefix = s:sub(1, -4)
            local num = prefix:match("(%d+)$")
            if num then
                formula = prefix:sub(1, -(#num + 1))
                charge  = num .. EN_DASH
            else
                formula = prefix
                charge  = EN_DASH
            end
        end
    end

    if formula then
        -- Normalise ASCII hyphen to Unicode minus sign
        charge = charge:gsub("%-", MINUS_SIGN)
        return formula, charge
    end

    return s, nil
end

-- Build a list of pandoc Inline elements from a chemical formula string.
-- Digits become Subscript elements; all other characters become Str elements.
-- If a trailing charge is detected, it is appended as a Superscript.
local function format_chem_generic(s)
    local formula, charge = split_charge(s)
    local inlines = pandoc.List()

    for i = 1, #formula do
        local c = formula:sub(i, i)
        if c:match("%d") then
            inlines:insert(pandoc.Subscript({pandoc.Str(c)}))
        else
            inlines:insert(pandoc.Str(c))
        end
    end

    if charge then
        inlines:insert(pandoc.Superscript({pandoc.Str(charge)}))
    end

    return inlines
end

-- Walk a string left-to-right, returning a list of typed segments:
--   {type="chem", content=formula}  for s:{...} patterns
--   {type="sub",  content=name}     for {name} patterns
--   {type="text", content=text}     for literal text between patterns
local function split_string(s)
    local segments = {}
    local pos = 1

    while pos <= #s do
        -- Find the next occurrence of each pattern from the current position.
        local chem_start, chem_end, chem_formula = s:find("s:%{([^%s%}]*)%}", pos)
        local sub_start,  sub_end,  sub_name     = s:find("%{([^%s%}]+)%}",   pos)

        if not chem_start and not sub_start then
            -- No more patterns; emit the remainder as text.
            table.insert(segments, {type="text", content=s:sub(pos)})
            break
        end

        local next_start, next_end, seg_type, seg_content

        -- Pick whichever pattern starts earliest; chem wins on a tie.
        if chem_start and (not sub_start or chem_start <= sub_start) then
            next_start, next_end = chem_start, chem_end
            seg_type    = "chem"
            seg_content = chem_formula
        else
            next_start, next_end = sub_start, sub_end
            seg_type    = "sub"
            seg_content = sub_name
        end

        -- Emit any literal text that precedes the matched pattern.
        if next_start > pos then
            table.insert(segments, {type="text", content=s:sub(pos, next_start - 1)})
        end

        table.insert(segments, {type=seg_type, content=seg_content})
        pos = next_end + 1
    end

    return segments
end

-- Expand chemical structure and substitution patterns within a Str element.
-- Returns a pandoc.List of Inline elements, or nil if the string contains no patterns.
local function process_str(str_elem, sub_dict)
    local s = str_elem.text

    -- Quick exit: neither pattern marker is present.
    if not s:find("s:%{") and not s:find("%{") then
        return nil
    end

    local segments = split_string(s)

    -- If no chem or sub segments were found, the string is unchanged.
    local has_pattern = false
    for _, seg in ipairs(segments) do
        if seg.type == "chem" or seg.type == "sub" then
            has_pattern = true
            break
        end
    end
    if not has_pattern then
        return nil
    end

    local result = pandoc.List()

    for _, seg in ipairs(segments) do
        if seg.type == "chem" then
            -- For LaTeX-based output, delegate to the mhchem package.
            if FORMAT == "latex" or FORMAT == "beamer" then
                result:insert(pandoc.RawInline("latex", "\\ce{" .. seg.content .. "}"))
            else
                result:extend(format_chem_generic(seg.content))
            end

        elseif seg.type == "sub" then
            if sub_dict and sub_dict[seg.content] then
                -- MetaInlines: insert each Inline element in order.
                for _, inline in ipairs(sub_dict[seg.content]) do
                    result:insert(inline)
                end
            else
                -- Unknown name: restore the original placeholder text.
                result:insert(pandoc.Str("{" .. seg.content .. "}"))
            end

        elseif seg.type == "text" and seg.content ~= "" then
            result:insert(pandoc.Str(seg.content))
        end
    end

    return result
end

-- Return the substitution dictionary from document metadata, or nil if absent.
-- Accepts either "substitutions" or the legacy key "compound names".
local function get_sub_dict(meta)
    if meta.substitutions then
        return meta.substitutions
    elseif meta["compound names"] then
        return meta["compound names"]
    end
    return nil
end

-- Entry point: read metadata once, then walk the full document expanding patterns.
function Pandoc(doc)
    local sub_dict = get_sub_dict(doc.meta)
    return doc:walk {
        Str = function(s) return process_str(s, sub_dict) end
    }
end
