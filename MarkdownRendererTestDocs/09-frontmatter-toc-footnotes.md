---
title: Markdown Renderer Test
date: 2026-06-27
tags:
  - markdown
  - renderer
draft: false
---

# Front Matter, TOC, Footnotes

上方 YAML Front matter 是否被隐藏、显示或解析，取决于你的产品设计。

[TOC]

## Footnotes

这里有一个脚注引用。[^one]

这里有另一个脚注引用。[^long-note]

[^one]: 这是第一个脚注。

[^long-note]: 这是一个较长脚注。
    它包含缩进续行。
    它还包含 `inline code` 和 **bold text**。

## Definition List

Term 1
: Definition 1

Term 2
: Definition 2 first paragraph
: Definition 2 second paragraph

## Abbreviations

HTML should maybe show abbreviation expansion if supported.

*[HTML]: HyperText Markup Language

## Math-Like Content

Inline math if supported: $E = mc^2$.

Block math if supported:

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

If math is unsupported, these should render as ordinary text without breaking the page.
