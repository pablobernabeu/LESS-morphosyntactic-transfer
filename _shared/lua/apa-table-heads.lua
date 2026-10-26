-- apa-table-heads.lua -- column-head alignment for the manuscript tables (APA 7)
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
  return tb
end
