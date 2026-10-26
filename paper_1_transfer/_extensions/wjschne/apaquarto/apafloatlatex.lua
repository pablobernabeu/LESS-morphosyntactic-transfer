if FORMAT ~= "latex" then
  return
end

local utilsapa = require("utilsapa")

local noteword = "Note"

-- from quarto-cli/src/resources/pandoc/datadir/init.lua
-- global quarto params
local paramsJson = quarto.base64.decode(os.getenv("QUARTO_FILTER_PARAMS"))
local quartoParams = quarto.json.decode(paramsJson)
local function param(name, default)
  -- get name from quartoParams, if possible
  local value = quartoParams[name]
  if value == nil then
    -- get name from quartoParams.language, if possible
    if quartoParams.language then
      value = quartoParams.language[name]
    end
    -- If still nil, then assign default
    if value == nil then
      value = default
    end
  end
  return value
end


-- Is the .pdf in journal mode?
local journalmode = false
local manuscriptmode = true
local noteprefix = "\\noindent\\textit{Note.}"
local beforenote = ""
local getmode = function(meta)
  local documentmode = pandoc.utils.stringify(meta["documentmode"])
  journalmode = documentmode == "jou"
  manuscriptmode = documentmode == "man"
  -- Find word for "note"
  if not meta.language["figure-table-note"] then
    if param("callout-note-title") then
      meta.language["figure-table-note"] = param("callout-note-title")
    end
  end
  -- LOCAL PATCH (2026-09-04), not upstream apaquarto 5.0.18.
  -- Quarto's LaTeX preamble issues \g@addto@macro\@floatboxreset{\centering},
  -- so the float package centres everything inside a figure or table float --
  -- the note included, which APA sets as ordinary running text. Restore the
  -- body's paragraph shape at the start of the note. \leftskip, \rightskip and
  -- \parfillskip are read when the paragraph is broken, so setting them here
  -- governs the whole note, and the assignment is confined to the float box, so
  -- the graphic above stays centred. Re-apply this if the extension is updated.
  noteprefix = "\\noindent \\leftskip=0pt \\rightskip=0pt \\parfillskip=0pt plus 1fil\\relax \\emph{" .. meta.language["figure-table-note"] .. ".} "
end



-- Split string function
--function string:split(delimiter)
--  local result               = {}
--  local from                 = 1
--  local delim_from, delim_to = string.find(self, delimiter, from)
--  while delim_from do
--    from                 = delim_to + 1
--    delim_from, delim_to = string.find(self, delimiter, from)
--  end
--  table.insert(result, string.sub(self, from))
--  return result
--end

local processfloat = function(float)
  if float.attributes["disable-apaquarto-processing"] then
    if not (float.attributes["disable-apaquarto-processing"] == "false") then
      return float
    end
  end
  -- default float position
  local floatposition = "[!htbp]"
  local p = {}
  local apanotedivs = pandoc.Div(pandoc.Blocks {})
  -- Reset this per float. The previous implementation let a table's compacting
  -- value leak into subsequent figures, pulling their notes into the plot.
  beforenote = ""
  if manuscriptmode then
    beforenote = "\\vspace{8pt}\n"
  end
  if float.attributes["fig-pos"] then
    if pandoc.utils.stringify(float.attributes["fig-pos"]) == "false" then
      floatposition = "[!htbp]"
    else
      floatposition = "[" .. float.attributes["fig-pos"] .. "]"
    end
  end

  if float.type == "Table" then
        -- credit to @michaelzehetleitne https://github.com/wjschne/apaquarto/issues/71
        -- Long-table mode: skip float wrapper so longtable can page-break
    --quarto.log.output(float.attributes)
    if float.attributes["apa-longtable"] == "true" and not journalmode then
      local blocks = pandoc.Blocks({})
      -- LOCAL PATCH (2026-09-18), not upstream apaquarto 5.0.18.
      -- A long table is set in the running text, not in a float, so its note
      -- inherited the manuscript's double spacing, while every figure note and
      -- the single-spaced table body above it are single-spaced. Set the note
      -- single-spaced (setspace's \setstretch; apatemplate.tex loads setspace)
      -- and flush left, so that the specific note of a list-form apa-note, a
      -- second paragraph, is not indented like running text. A group is used
      -- in place of the singlespace environment, whose opening \vskip widened
      -- the gap between table and note by half a line. The space after the
      -- group matches the separation a float keeps from the text below it.
      -- Paper 1 addition (this copy only): a table is kept with its note.
      -- Set after the longtable, a note could be cut off from it: longtable
      -- packs the part of a table on its last page into one box, so nothing on
      -- that page can move once the table is set, and a note that did not fit
      -- went to the next page alone, above the next table's caption. The note is
      -- therefore typeset into a box before the table (with the caption title,
      -- to measure both) and set as the table's last row by \LESnoteintable, so
      -- that longtable's own page breaking keeps it with the last rows.
      -- \LESneedtable then decides where the table starts: a table that fits in
      -- a set share of the page moves to the next page whole when it does not
      -- fit on this one. Both macros are defined in the Paper 1 header-includes.
      -- A table withheld from the draft is a placeholder paragraph with no
      -- longtable, and its note follows it as before, breakable only with at
      -- least two lines on each page.
      -- Re-apply this if the extension is updated.
      local nrows = 0
      local found = false
      if float.content and float.content.walk then
        float.content:walk({
          Table = function(tb)
            found = true
            nrows = nrows + #tb.head.rows + #tb.foot.rows
            for _, b in ipairs(tb.bodies) do nrows = nrows + #b.head + #b.body end
          end
        })
      end
      -- A table withheld from the draft is a one-line placeholder paragraph.
      if not found then nrows = 2 end
      local capinl = pandoc.Inlines({})
      if float.caption_long then
        if float.caption_long.content then
          capinl = float.caption_long.content
        else
          capinl = pandoc.utils.blocks_to_inlines(float.caption_long)
        end
      end
      local kept = pandoc.Blocks({})
      if float.attributes["apa-note"] then
        local bn = ""
        if manuscriptmode then
          bn = "\\vspace{8pt}\n"
          if float.attributes["beforenotespace"] then
            bn = "\\vspace{" .. float.attributes["beforenotespace"] .. "}\n"
          end
        end
        local npfx = pandoc.Span(pandoc.RawInline("latex", bn .. noteprefix))
        local note = utilsapa.make_note(float.attributes["apa-note"], npfx)
        for i, b in ipairs(note.content) do
          if i > 1 then kept:insert(pandoc.RawBlock("latex", "\\nobreak")) end
          kept:insert(b)
        end
      end
      local notesetup = "\\setstretch{1}\\setlength{\\parindent}{0pt}" ..
        "\\clubpenalty=10000 \\widowpenalty=10000 "
      blocks:insert(pandoc.RawBlock("latex",
        "\\setbox\\LEScapbox\\vbox{\\hsize\\linewidth\\setstretch{1}\\normalsize\\itshape\\noindent"))
      blocks:insert(pandoc.Plain(capinl:clone()))
      blocks:insert(pandoc.RawBlock("latex", "\\par}"))
      blocks:insert(pandoc.RawBlock("latex", "\\setbox\\LESnotebox\\vbox{\\hsize\\linewidth" .. notesetup))
      if #kept > 0 then blocks:insert(pandoc.Div(kept:clone())) end
      blocks:insert(pandoc.RawBlock("latex", "\\par}"))
      local notein = found and #kept > 0
      blocks:insert(pandoc.RawBlock("latex",
        "\\LESneedtable" .. (found and "[\\LTpre]" or "") .. "{" .. nrows .. "}" ..
        (notein and "\n\\begingroup\\LESnoteintable" or "")))
      -- Use Quarto's native longtable output (caption + label included)
      if float.__quarto_custom_node then
        blocks:insert(float.__quarto_custom_node)
      else
        blocks:insert(float.content)
      end
      if notein then
        blocks:insert(pandoc.RawBlock("latex", "\\endgroup\\addvspace{12pt}"))
      elseif #kept > 0 then
        -- Append apa-note if present
        blocks:insert(pandoc.RawBlock("latex", "\\begingroup" .. notesetup))
        blocks:insert(pandoc.Div(kept))
        blocks:insert(pandoc.RawBlock("latex", "\\par\\endgroup\\addvspace{12pt}"))
      end
      return pandoc.Div(blocks)
    end
    -- Default table environment
    local latextableenv = "table"
    -- Manuscript spacing before note needs adjustment ment
    if manuscriptmode then
      beforenote = "\\vspace{8pt}\n"
      if float.attributes["beforenotespace"] then
        beforenote = "\\vspace{" .. float.attributes["beforenotespace"] .. "}\n"
      end
    end
    if journalmode then
      -- No spacing in before note in journalmode
      beforenote = ""
      if float.attributes["beforenotespace"] then
        beforenote = "\\vspace{" .. float.attributes["beforenotespace"] .. "}\n"
      end
      -- Table environment in journal mode
      latextableenv = "ThreePartTable"
    end

    -- Table enironment for apa-twocolumn floats
    if float.attributes then
      if float.attributes["apa-twocolumn"] then
        if float.attributes["apa-twocolumn"] == "true" then
          if journalmode then
            latextableenv = "twocolumntable"
          end
        end
      end
    end

    -- Add note
    if float.attributes["apa-note"] then
      local note_prefix = pandoc.Span(pandoc.RawInline("latex", beforenote .. noteprefix))
      apanotedivs = utilsapa.make_note(float.attributes["apa-note"], note_prefix)
    end

    local captionsubspan = pandoc.Span({
      pandoc.RawInline("latex", "\\label"),
      pandoc.RawInline("latex", "{"),
      pandoc.RawInline("latex", float.identifier),
      pandoc.RawInline("latex", "}")
    })

    -- Adjust space after caption in manuscript mode
    local aftercaption = ""
    if manuscriptmode then
      aftercaption = "\n\\vspace{-20pt}"
      if float.attributes["after-caption-space"] then
        aftercaption = "\\vspace{" .. float.attributes["after-caption-space"] .. "}\n"
      end
    end

    -- Make caption
    local captionspan = pandoc.Span({
      pandoc.RawInline("latex", "\\caption"),
      pandoc.RawInline("latex", "{"),
      pandoc.Span(float.caption_long.content),
      captionsubspan,
      pandoc.RawInline("latex", "}" .. aftercaption)

    })


    -- Make table
    local returnblock = pandoc.Div({
      pandoc.RawBlock("latex", "\\begin{" .. latextableenv .. "}"),
      captionspan,
      float.content

    }
    )
    returnblock.content:extend({ apanotedivs })


    returnblock.content:extend({ pandoc.RawBlock("latex", "\\end{" .. latextableenv .. "}") })

    if journalmode then
      returnblock = pandoc.Div({
        pandoc.RawBlock("latex", "\\begin{" .. latextableenv .. "}"),
        float.__quarto_custom_node,
        apanotedivs,
        pandoc.RawBlock("latex", "\\end{" .. latextableenv .. "}")
      })
    end

    return returnblock
  end

  if float.type == "Figure" then
    local hasnote = false
    local apanote
    local twocolumn = false
    local latexenv = "figure"
    -- Get apa-note from image, if possible
    float.content:walk {
      Image = function(img)
        if img.attributes["apa-note"] then
          hasnote = true
          apanote = img.attributes["apa-note"]
        end

        if img.attributes["beforenotespace"] then
          beforenote = "\\vspace{" .. img.attributes["beforenotespace"] .. "}\n"
        end
        if img.attributes["apa-twocolumn"] then
          if img.attributes["apa-twocolumn"] == "true" then
            if journalmode then
              twocolumn = true
            end
          end
        end
      end
    }

    if twocolumn then
      latexenv = "figure*"
    end

    -- Make note
    if hasnote or twocolumn then
      if hasnote then
        -- Add note
        if float.attributes["apa-note"] then
          local note_prefix = pandoc.Span(pandoc.RawInline("latex", beforenote .. noteprefix))
          apanotedivs = utilsapa.make_note(float.attributes["apa-note"], note_prefix)
        end
      end

      local captionsubspan = pandoc.Span({
        pandoc.RawInline("latex", "\\label"),
        pandoc.RawInline("latex", "{"),
        pandoc.Str(float.identifier),
        pandoc.RawInline("latex", "}")
      })

      local captionspan = pandoc.Span({
        pandoc.RawInline("latex", "\\caption"),
        pandoc.RawInline("latex", "{"),
        pandoc.Span(float.caption_long.content),
        captionsubspan,
        pandoc.RawInline("latex", "}")
      })

      if float.attributes.prefix ~= "" then
        floatposition = ""
      end

      local returnblock = pandoc.Div({
        pandoc.RawBlock("latex", "\\begin{" .. latexenv .. "}" .. floatposition),
        captionspan,
        float.content,
        apanotedivs,
        pandoc.RawBlock("latex", "\\end{" .. latexenv .. "}")
      })

      return returnblock
    end
  end
end


return {
  { Meta = getmode },
  { FloatRefTarget = processfloat }
}
