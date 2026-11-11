-- AST-level table semantics and links between the three packaged documents.
function Table(t)
    for _,row in ipairs(t.head.rows or {}) do
        for _,cell in ipairs(row.cells or {}) do cell.attr.attributes.scope='col' end
    end
    return t
end
function Link(link)
    if link.target:match('^[A-Z%-]+%.md$') then
        link.target=link.target:gsub('%.md$','.html')
    end
    return link
end
