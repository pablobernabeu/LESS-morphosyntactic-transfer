-- apa-table-heads.lua -- column heads and numeric columns of the manuscript tables (APA 7)
--
-- Registered by both manuscripts and the Paper 2 supplement (filters: in each YAML
-- header). A spanner is centred over the columns it spans, and the head of a
-- right-aligned or centred (numeric) column is centred over it. Heads of left-aligned
-- text columns, the stub head included, stay flush left with their column. Pandoc
-- otherwise gives every head the alignment of its column, which leaves a spanner flush
-- left over its columns and a numeric head flush right over its numbers. The cell
-- alignment reaches both outputs: the LaTeX longtable and the Word table.
--
-- Exact column widths (opt-in). Pandoc takes a grid table's relative column widths from
-- its dash counts, but divides them by the larger of the grid's width in characters and
-- --columns (72). Any grid wider than 72 characters is therefore set across the full
-- measure, whatever fractions it was written with, and a narrow table with long cell
-- source (a maths head, a LaTeX macro) is stretched with it. A table can instead name its
-- widths: a Span in a head cell carrying les-widths="w1 w2 ..." (fractions of the text
-- width, one per column) sets them exactly, and les-widths-docx, when present, replaces
-- them in Word, whose tables are set at 12 pt against 10 pt in the PDF. The Span is
-- unwrapped, so only its text is printed. Tables without such a Span are left as Pandoc
-- read them.
--
-- Numeric columns. The table writer, les_grid_table() in
-- _shared/R/06_manuscript_helpers.R, marks a numeric column by aligning it right or
-- centre. Each number in such a column is padded, on both sides of its decimal point,
-- with invisible copies of the characters it lacks against the column's other numbers,
-- so that every number takes the same width, and the column is then centred. Numbers of
-- one width centred in their column align on the decimal point and sit as a block under
-- their centred head. Right alignment alone left each number flush with the right edge
-- of a column that Pandoc sets wider than its widest cell, off to the right of its head.
-- The padding is added here, after Pandoc has read the grid table, so that it cannot
-- widen the grid's columns. The PDF pads with \phantom, which is exact. Word pads with
-- the Unicode spaces whose widths in Times New Roman, the Word font, match the missing
-- characters: a figure space for a digit (0.5 em), a punctuation space for a comma or
-- point (0.25 em), and a figure space and a hair space for a minus or comparison sign
-- (0.584 em for 0.564 em). Word joiners between them stop Word breaking a line inside
-- the padding. A cell that is not a number (a blank, an em dash, a word) is left as it
-- is and centred. A trailing superscript, a note mark, is left out of the count,
-- because the manuscript gives the unmarked cells of a marked column an invisible mark
-- of the same width (Paper 1's .conv_align_marks()).
local function exact_widths(tb)
  local spec
  local unwrap = {
    Span = function(sp)
      local w = sp.attributes["les-widths"]
      if w == nil then return nil end
      spec = (FORMAT:match("docx") and sp.attributes["les-widths-docx"]) or w
      return sp.content
    end
  }
  for _, row in ipairs(tb.head.rows) do
    for _, cell in ipairs(row.cells) do
      cell.contents = cell.contents:walk(unwrap)
    end
  end
  if spec == nil then return end
  local i = 0
  for v in spec:gmatch("[^%s,]+") do
    i = i + 1
    if tb.colspecs[i] and tonumber(v) then
      tb.colspecs[i] = { tb.colspecs[i][1], tonumber(v) }
    end
  end
end

local NBSP, WJ = "\u{00A0}", "\u{2060}"

-- The characters a number may hold besides its digits; any other character makes a
-- cell text. The space is the one in "> .999".
local NUMERIC = {}
for _, ch in ipairs({ ",", ".", "\u{2212}", "-", "+", "<", ">", "\u{2264}", "\u{2265}",
                      "%", " ", NBSP }) do
  NUMERIC[ch] = true
end

local function is_digit(ch) return ch:match("^%d$") ~= nil end

-- The width class of a character. The digits share one, since every digit of both
-- fonts is as wide as every other, and so do the two spaces.
local function class_of(ch)
  if is_digit(ch) then return "0" end
  if ch == " " then return NBSP end
  return ch
end

-- Counts the width classes on either side of a number's decimal point, or of the end of
-- its digits when it has none. Returns nil for a cell that is not a number.
local function measure(s)
  local chars, digits = {}, 0
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if is_digit(ch) then
      digits = digits + 1
    elseif not NUMERIC[ch] then
      return nil
    end
    chars[#chars + 1] = ch
  end
  if digits == 0 then return nil end
  local anchor
  for i = 1, #chars - 1 do
    if chars[i] == "." and is_digit(chars[i + 1]) then anchor = i; break end
  end
  if anchor == nil then
    for i = #chars, 1, -1 do
      if is_digit(chars[i]) then anchor = i + 1; break end
    end
  end
  local m = { left = {}, right = {} }
  for i, ch in ipairs(chars) do
    local side = (i < anchor) and m.left or m.right
    local k = class_of(ch)
    side[k] = (side[k] or 0) + 1
  end
  return m
end

local TEX = { [">"] = "\\textgreater{}", ["<"] = "\\textless{}", ["%"] = "\\%", [NBSP] = "~" }
local WORD = { ["0"] = "\u{2007}", [","] = "\u{2008}", ["."] = "\u{2008}", [NBSP] = NBSP,
               ["-"] = "\u{2004}", ["%"] = "\u{2007}" .. WJ .. "\u{2004}" }
local WORD_SIGN = "\u{2007}" .. WJ .. "\u{200A}"

-- The padding standing for the characters a number lacks, or nil when it lacks none.
local function padding(lack, leading)
  local latex = FORMAT:match("latex") ~= nil
  local parts = {}
  for k, n in pairs(lack) do
    for _ = 1, n do
      parts[#parts + 1] = latex and (TEX[k] or k) or (WORD[k] or WORD_SIGN)
    end
  end
  if #parts == 0 then return nil end
  if latex then
    -- \phantom does not start a paragraph, so a phantom that opens a cell would be set
    -- as a line of its own above the number without the \leavevmode.
    return pandoc.RawInline("latex", (leading and "\\leavevmode" or "") ..
                                     "\\phantom{" .. table.concat(parts) .. "}")
  end
  return pandoc.Str(WJ .. table.concat(parts, WJ) .. WJ)
end

local function single_block(cell)
  local b = cell.contents
  if #b == 1 and (b[1].t == "Plain" or b[1].t == "Para") then return b[1] end
  return nil
end

local function pad_numeric_columns(tb)
  local numeric = {}
  for j, spec in ipairs(tb.colspecs) do
    numeric[j] = spec[1] == pandoc.AlignRight or spec[1] == pandoc.AlignCenter
  end
  local found = {}
  for _, body in ipairs(tb.bodies) do
    for _, row in ipairs(body.body) do
      local col = 1
      for _, cell in ipairs(row.cells) do
        -- A row span would shift the columns of the rows below it. The writer emits
        -- none, so a table that has one is left as Pandoc read it.
        if cell.row_span > 1 then return end
        local blk = cell.col_span == 1 and numeric[col] and single_block(cell)
        if blk then
          local inl = blk.content
          local mark = #inl > 0 and inl[#inl].t == "Superscript"
          local main = mark and pandoc.Inlines({ table.unpack(inl, 1, #inl - 1) }) or inl
          local m = measure(pandoc.utils.stringify(main))
          if m then
            found[col] = found[col] or {}
            table.insert(found[col], { cell = cell, blk = blk, mark = mark, m = m })
          end
        end
        col = col + cell.col_span
      end
    end
  end
  for j, list in pairs(found) do
    local most = { left = {}, right = {} }
    for _, c in ipairs(list) do
      for side, counts in pairs(c.m) do
        for k, n in pairs(counts) do most[side][k] = math.max(most[side][k] or 0, n) end
      end
    end
    for _, c in ipairs(list) do
      local lack = { left = {}, right = {} }
      for side, counts in pairs(most) do
        for k, n in pairs(counts) do lack[side][k] = n - (c.m[side][k] or 0) end
      end
      local inl, out = c.blk.content, pandoc.Inlines({})
      local before, after = padding(lack.left, true), padding(lack.right, false)
      if before then out:insert(before) end
      for i = 1, #inl - (c.mark and 1 or 0) do out:insert(inl[i]) end
      if after then out:insert(after) end
      if c.mark then out:insert(inl[#inl]) end
      c.blk.content = out
      c.cell.contents = pandoc.Blocks({ c.blk })
    end
    tb.colspecs[j] = { pandoc.AlignCenter, tb.colspecs[j][2] }
  end
end

function Table(tb)
  exact_widths(tb)
  for _, row in ipairs(tb.head.rows) do
    local col = 1
    for _, cell in ipairs(row.cells) do
      local a = tb.colspecs[col][1]
      if cell.col_span > 1 or a == pandoc.AlignRight or a == pandoc.AlignCenter then
        cell.alignment = pandoc.AlignCenter
      end
      col = col + cell.col_span
    end
  end
  pad_numeric_columns(tb)
  return tb
end
