package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:path/slashpath"
import "core:strconv"
import "core:strings"

Article :: struct {
	source_path:     string,
	source_relative: string,
	route:           string,
	output_path:     string,
	title:           string,
	description:     string,
	order:           int,
	body:            string,
	html:            string,
}

Nav_Node :: struct {
	segment:       string,
	article_index: int,
	children:      [dynamic]int,
}

main :: proc() {
	if len(os.args) != 3 {
		fmt.eprintln("usage: docsgen <source-directory> <output-directory>")
		os.exit(2)
	}

	source_dir := os.args[1]
	output_dir := os.args[2]
	articles := collect_articles(source_dir)
	if len(articles) == 0 {
		fmt.panicf("no markdown articles found in %s", source_dir)
	}

	sort_articles(articles[:])
	for &article in articles {
		article.route = article_route(article.source_relative)
		article.output_path = article_output_path(output_dir, article.route)
	}

	nodes := build_navigation(articles[:])
	for &article in articles {
		article.html = render_markdown(article, articles[:])
	}

	for article in articles {
		page := render_page(article, articles[:], nodes[:])
		output_dirname, _ := filepath.split(article.output_path)
		if err := os.make_directory_all(output_dirname); err != nil && err != .Exist {
			fmt.panicf("could not create %s: %v", output_dirname, err)
		}
		if err := os.write_entire_file(article.output_path, transmute([]byte)page); err != nil {
			fmt.panicf("could not write %s: %v", article.output_path, err)
		}
	}

	fmt.printfln("[docsgen] generated %d articles", len(articles))
}

collect_articles :: proc(source_dir: string) -> [dynamic]Article {
	articles := make([dynamic]Article)
	source_absolute, err := filepath.abs(source_dir, context.allocator)
	if err != nil {
		fmt.panicf("could not resolve source directory %s: %v", source_dir, err)
	}

	walker := os.walker_create(source_absolute)
	defer os.walker_destroy(&walker)

	for info in os.walker_walk(&walker) {
		if info.type != .Regular || !strings.has_suffix(info.name, ".md") {
			continue
		}

		file_absolute, abs_err := filepath.abs(info.fullpath, context.allocator)
		if abs_err != nil {
			fmt.panicf("could not resolve article path %s: %v", info.fullpath, abs_err)
		}
		relative, relative_err := filepath.rel(source_absolute, file_absolute)
		if relative_err != .None {
			fmt.panicf("could not find article path relative to %s: %s", source_dir, info.fullpath)
		}
		relative = url_path(relative)

		data, read_err := os.read_entire_file(file_absolute, context.allocator)
		if read_err != nil {
			fmt.panicf("could not read %s: %v", file_absolute, read_err)
		}

		article := parse_article(file_absolute, relative, string(data))
		append(&articles, article)
	}

	if path, walk_err := os.walker_error(&walker); walk_err != nil {
		fmt.panicf("could not scan %s at %s: %v", source_dir, path, walk_err)
	}

	return articles
}

parse_article :: proc(source_path, relative, source: string) -> Article {
	lines, split_err := strings.split_lines(source)
	if split_err != nil {
		fmt.panicf("could not split %s into lines: %v", source_path, split_err)
	}
	if len(lines) < 3 || lines[0] != "---" {
		fmt.panicf("%s is missing front matter", source_path)
	}

	closing := -1
	for i := 1; i < len(lines); i += 1 {
		if lines[i] == "---" {
			closing = i
			break
		}
	}
	if closing < 0 {
		fmt.panicf("%s has unterminated front matter", source_path)
	}

	article := Article{
		source_path = source_path,
		source_relative = relative,
		order = 1000,
	}
	for line in lines[1:closing] {
		colon := strings.index_byte(line, ':')
		if colon <= 0 {
			fmt.panicf("%s has malformed front matter line: %s", source_path, line)
		}

		key := strings.trim_space(line[:colon])
		value := strings.trim_space(line[colon+1:])
		if len(value) >= 2 && ((value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'')) {
			value = value[1:len(value)-1]
		}

		switch key {
		case "title":
			article.title = value
		case "description":
			article.description = value
		case "order":
			order, ok := strconv.parse_int(value)
			if !ok {
				fmt.panicf("%s has an invalid order: %s", source_path, value)
			}
			article.order = order
		case "":
			continue
		case:
			fmt.panicf("%s has unknown front matter field: %s", source_path, key)
		}
	}
	if article.title == "" {
		fmt.panicf("%s is missing a title", source_path)
	}

	body_builder := strings.builder_make()
	for line in lines[closing+1:] {
		fmt.sbprintfln(&body_builder, "%s", line)
	}
	article.body = strings.to_string(body_builder)
	return article
}

sort_articles :: proc(articles: []Article) {
	for i := 1; i < len(articles); i += 1 {
		j := i
		for j > 0 && article_less(articles[j], articles[j-1]) {
			articles[j], articles[j-1] = articles[j-1], articles[j]
			j -= 1
		}
	}
}

article_less :: proc(left, right: Article) -> bool {
	if left.order != right.order {
		return left.order < right.order
	}
	return left.source_relative < right.source_relative
}

build_navigation :: proc(articles: []Article) -> [dynamic]Nav_Node {
	nodes := make([dynamic]Nav_Node)
	append(&nodes, Nav_Node{article_index = -1})

	for article, article_index in articles {
		without_extension := article.source_relative[:len(article.source_relative)-len(".md")]
		if strings.has_suffix(without_extension, "/index") {
			without_extension = without_extension[:len(without_extension)-len("/index")]
		} else if without_extension == "index" {
			without_extension = ""
		}

		current := 0
		if without_extension != "" {
			for segment in strings.split(without_extension, "/") {
				if segment == "" {
					continue
				}
				child := navigation_child(nodes[:], current, segment)
				if child < 0 {
					child = len(nodes)
					append(&nodes, Nav_Node{segment = segment, article_index = -1})
					append(&nodes[current].children, child)
				}
				current = child
			}
		}
		nodes[current].article_index = article_index
	}

	return nodes
}

navigation_child :: proc(nodes: []Nav_Node, parent: int, segment: string) -> int {
	for child in nodes[parent].children {
		if nodes[child].segment == segment {
			return child
		}
	}
	return -1
}

article_route :: proc(relative: string) -> string {
	without_extension := relative[:len(relative)-len(".md")]
	if without_extension == "index" {
		return "/docs/"
	}
	if strings.has_suffix(without_extension, "/index") {
		return fmt.aprintf("/docs/%s/", without_extension[:len(without_extension)-len("/index")])
	}
	return fmt.aprintf("/docs/%s/", without_extension)
}

article_output_path :: proc(output_dir, route: string) -> string {
	route_path := strings.trim(route, "/")
	return join_path(output_dir, route_path, "index.html")
}

join_path :: proc(parts: ..string) -> string {
	joined, err := filepath.join(parts[:], context.allocator)
	if err != nil {
		fmt.panicf("could not join path: %v", err)
	}
	return joined
}

url_path :: proc(path: string) -> string {
	builder := strings.builder_make()
	for c in transmute([]byte)path {
		if c == '\\' {
			strings.write_byte(&builder, '/')
		} else {
			strings.write_byte(&builder, c)
		}
	}
	return strings.to_string(builder)
}

render_page :: proc(article: Article, articles: []Article, nodes: []Nav_Node) -> string {
	builder := strings.builder_make()
	is_overview := article.route == "/docs/"
	title := "inso documentation"
	if !is_overview {
		title = fmt.aprintf("%s | inso documentation", article.title)
	}

	fmt.sbprintfln(&builder, `<!doctype html>`)
	fmt.sbprintfln(&builder, `<html lang="en">`)
	fmt.sbprintfln(&builder, `    <head>`)
	fmt.sbprintfln(&builder, `        <meta charset="utf-8" />`)
	fmt.sbprintfln(&builder, `        <meta name="viewport" content="width=device-width, initial-scale=1" />`)
	fmt.sbprintfln(&builder, `        <meta name="description" content="%s" />`, escape_html(article.description))
	fmt.sbprintfln(&builder, `        <title>%s</title>`, escape_html(title))
	fmt.sbprintfln(&builder, `        <link rel="icon" type="image/x-icon" href="/res/favicon.ico" />`)
	fmt.sbprintfln(&builder, `        <link rel="preload" href="/res/OCRA.woff2" as="font" type="font/woff2" crossorigin="anonymous" />`)
	fmt.sbprintfln(&builder, `        <link rel="preload" href="/res/noto-mono.woff2" as="font" type="font/woff2" crossorigin="anonymous" />`)
	fmt.sbprintfln(&builder, `        <link rel="stylesheet" href="/res/style.css" />`)
	fmt.sbprintfln(&builder, `        <script src="/res/site.js" defer></script>`)
	fmt.sbprintfln(&builder, `    </head>`)
	fmt.sbprintfln(&builder, `    <body class="docs-body">`)
	fmt.sbprintfln(&builder, `        <a class="docs-logo" href="/" aria-label="back to inso home">`)
	fmt.sbprintfln(&builder, `            <img src="/res/insooutline.png" alt="inso" />`)
	fmt.sbprintfln(&builder, `        </a>`)
	fmt.sbprintfln(&builder, `        <div class="docs-page">`)
	fmt.sbprintfln(&builder, `            <div class="docs-layout">`)
	fmt.sbprintfln(&builder, `                <aside class="docs-sidebar">`)
	if is_overview {
		fmt.sbprintfln(&builder, `                    <a class="docs-tree-root" href="/docs/" aria-current="page">inso_docs/</a>`)
	} else {
		fmt.sbprintfln(&builder, `                    <a class="docs-tree-root" href="/docs/">inso_docs/</a>`)
	}
	fmt.sbprintfln(&builder, `                    <nav class="docs-tree-nav" aria-label="documentation sections">`)
		render_navigation(&builder, nodes, 0, articles, article.route)
		fmt.sbprintfln(&builder, `                        <a class="docs-nav-link docs-file-link" href="/docs/lua_api.html"><svg class="docs-file-icon" viewBox="0 0 16 16" aria-hidden="true"><use xlink:href="#file-icon"></use></svg>lua_api.html</a>`)
	fmt.sbprintfln(&builder, `                    </nav>`)
	fmt.sbprintfln(&builder, `                    <a class="docs-home" href="/">&lt; HOME</a>`)
	fmt.sbprintfln(&builder, `                </aside>`)
	fmt.sbprintfln(&builder, `                <main class="docs-content">`)
	fmt.sbprintfln(&builder, `                    <article>`)
	fmt.sbprintfln(&builder, `                        <h1 class="docs-path"><a class="docs-path-root" href="/docs/">documentation</a><span class="docs-path-separator">/</span><strong>%s</strong></h1>`, escape_html(article.title))
	fmt.sbprintfln(&builder, `                        %s`, article.html)
	if is_overview {
		render_overview_cards(&builder, nodes, articles)
	}
	fmt.sbprintfln(&builder, `                    </article>`)
	fmt.sbprintfln(&builder, `                    <a class="docs-back" href="/docs/">&lt; BACK</a><span class="docs-path-separator"> / </span><a class="docs-back" href="#">SCROLL TO TOP ^</a>`)
	fmt.sbprintfln(&builder, `                </main>`)
	fmt.sbprintfln(&builder, `            </div>`)
	fmt.sbprintfln(&builder, `        </div>`)
	fmt.sbprintfln(&builder, `        <svg width="100%%" height="100%%" style="display: none" preserveAspectRatio="xMidYMid" fill="#000000" aria-hidden="true" focusable="false">`)
	fmt.sbprintfln(&builder, `            <symbol id="file-icon" viewBox="0 0 16 16">`)
	fmt.sbprintfln(&builder, `                <path d="M3 1.5h6l4 4v9H3z M9 1.5v4h4" fill="none" stroke="currentColor" stroke-width="1" />`)
	fmt.sbprintfln(&builder, `            </symbol>`)
	fmt.sbprintfln(&builder, `        </svg>`)
	fmt.sbprintfln(&builder, `    </body>`)
	fmt.sbprintfln(&builder, `</html>`)
	return strings.to_string(builder)
}

render_navigation :: proc(builder: ^strings.Builder, nodes: []Nav_Node, parent: int, articles: []Article, current_route: string) {
	fmt.sbprintfln(builder, `                        <ul>`)
	for child in nodes[parent].children {
		node := nodes[child]
		if node.article_index >= 0 {
			article := articles[node.article_index]
			if article.route == current_route {
				fmt.sbprintfln(builder, `                            <li><a class="docs-nav-link" href="%s" aria-current="page">%s</a>`, article.route, escape_html(article.title))
			} else {
				fmt.sbprintfln(builder, `                            <li><a class="docs-nav-link" href="%s">%s</a>`, article.route, escape_html(article.title))
			}
		} else {
			fmt.sbprintfln(builder, `                            <li><span class="docs-nav-group">%s</span>`, escape_html(node.segment))
		}
		if len(node.children) > 0 {
			render_navigation(builder, nodes, child, articles, current_route)
		}
		fmt.sbprintfln(builder, `                            </li>`)
	}
	fmt.sbprintfln(builder, `                        </ul>`)
}

render_overview_cards :: proc(builder: ^strings.Builder, nodes: []Nav_Node, articles: []Article) {
	fmt.sbprintfln(builder, `                            <div class="docs-card-list">`)
	for child in nodes[0].children {
		node := nodes[child]
		if node.article_index < 0 {
			continue
		}
		article := articles[node.article_index]
		fmt.sbprintfln(builder, `                                <a class="docs-card" href="%s">`, article.route)
		fmt.sbprintfln(builder, `                                    <strong>%s</strong>`, escape_html(article.title))
		fmt.sbprintfln(builder, `                                    <span>%s</span>`, escape_html(article.description))
		fmt.sbprintfln(builder, `                                </a>`)
	}
	fmt.sbprintfln(builder, `                            </div>`)
}

render_markdown :: proc(article: Article, articles: []Article) -> string {
	lines, split_err := strings.split_lines(article.body)
	if split_err != nil {
		fmt.panicf("could not split %s into lines: %v", article.source_path, split_err)
	}

	builder := strings.builder_make()
	heading_ids := make([dynamic]string)
	i := 0
	for i < len(lines) {
		line := lines[i]
		if strings.trim_space(line) == "" {
			i += 1
			continue
		}

		if language, is_fence := code_fence(line); is_fence {
			fmt.sbprintf(&builder, `                            <pre><code%s>`, code_language_attribute(language))
			i += 1
			closed := false
			first_code_line := true
			for i < len(lines) {
				if strings.trim_space(lines[i]) == "```" {
					closed = true
					i += 1
					break
				}
				if !first_code_line {
					strings.write_byte(&builder, '\n')
				}
				strings.write_string(&builder, escape_html(lines[i]))
				first_code_line = false
				i += 1
			}
			if !closed {
				fmt.panicf("%s has an unterminated code block", article.source_path)
			}
			strings.write_string(&builder, "</code></pre>\n")
			continue
		}

		if level, heading_text, is_heading := heading(line); is_heading {
			id := unique_heading_id(heading_text, &heading_ids)
			fmt.sbprintf(&builder, `                            <h%d id="%s">`, level, escape_html(id))
			render_inline(&builder, heading_text, article, articles)
			fmt.sbprintfln(&builder, `</h%d>`, level)
			i += 1
			continue
		}

		if i+1 < len(lines) && is_table_separator(lines[i+1]) && strings.index_byte(line, '|') >= 0 {
			i = render_table(&builder, lines, i, article, articles)
			continue
		}

		if _, _, is_list := list_item(line); is_list {
			i = render_list(&builder, lines, i, article, articles)
			continue
		}

		if is_horizontal_rule(line) {
			fmt.sbprintfln(&builder, `                            <hr />`)
			i += 1
			continue
		}

		paragraph := strings.builder_make()
		first_line := true
		for i < len(lines) && strings.trim_space(lines[i]) != "" {
			if !first_line && is_block_start(lines, i) {
				break
			}
			if !first_line {
				strings.write_string(&paragraph, " ")
			}
			strings.write_string(&paragraph, strings.trim_space(lines[i]))
			first_line = false
			i += 1
		}
		fmt.sbprintf(&builder, `                            <p>`)
		render_inline(&builder, strings.to_string(paragraph), article, articles)
		fmt.sbprintfln(&builder, `</p>`)
	}

	return strings.to_string(builder)
}

is_block_start :: proc(lines: []string, index: int) -> bool {
	if _, ok := code_fence(lines[index]); ok {
		return true
	}
	if _, _, ok := heading(lines[index]); ok {
		return true
	}
	if _, _, ok := list_item(lines[index]); ok {
		return true
	}
	if is_horizontal_rule(lines[index]) {
		return true
	}
	return index+1 < len(lines) && strings.index_byte(lines[index], '|') >= 0 && is_table_separator(lines[index+1])
}

code_fence :: proc(line: string) -> (language: string, ok: bool) {
	trimmed := strings.trim_space(line)
	if !strings.has_prefix(trimmed, "```") {
		return "", false
	}
	return strings.trim_space(trimmed[3:]), true
}

code_language_attribute :: proc(language: string) -> string {
	if language == "" {
		return ""
	}
	return fmt.aprintf(` class="language-%s"`, escape_html(language))
}

heading :: proc(line: string) -> (level: int, text: string, ok: bool) {
	if len(line) < 2 {
		return
	}
	level = 0
	for level < len(line) && line[level] == '#' {
		level += 1
	}
	if level == 0 || level > 6 || level >= len(line) || line[level] != ' ' {
		return 0, "", false
	}
	return level, strings.trim_space(line[level+1:]), true
}

unique_heading_id :: proc(text: string, used: ^[dynamic]string) -> string {
	base := slugify(text)
	if base == "" {
		base = "section"
	}
	id := base
	count := 2
	for {
		found := false
		for existing in used {
			if existing == id {
				found = true
				break
			}
		}
		if !found {
			append(used, id)
			return id
		}
		id = fmt.aprintf("%s-%d", base, count)
		count += 1
	}
}

slugify :: proc(text: string) -> string {
	builder := strings.builder_make()
	dashed := false
	for c in transmute([]byte)text {
		if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') {
			strings.write_byte(&builder, c)
			dashed = false
		} else if c >= 'A' && c <= 'Z' {
			strings.write_byte(&builder, c + ('a' - 'A'))
			dashed = false
		} else if !dashed && strings.builder_len(builder) > 0 {
			strings.write_byte(&builder, '-')
			dashed = true
		}
	}
	result := strings.to_string(builder)
	if strings.has_suffix(result, "-") {
		result = result[:len(result)-1]
	}
	return result
}

is_table_separator :: proc(line: string) -> bool {
	trimmed := strings.trim_space(line)
	if strings.index_byte(trimmed, '|') < 0 {
		return false
	}
	parts := strings.split(trimmed, "|")
	valid_cells := 0
	for part in parts {
		cell := strings.trim_space(part)
		if cell == "" {
			continue
		}
		if cell[0] == ':' {
			cell = cell[1:]
		}
		if len(cell) > 0 && cell[len(cell)-1] == ':' {
			cell = cell[:len(cell)-1]
		}
		if len(cell) < 3 {
			return false
		}
		for c in transmute([]byte)cell {
			if c != '-' {
				return false
			}
		}
		valid_cells += 1
	}
	return valid_cells >= 1
}

render_table :: proc(builder: ^strings.Builder, lines: []string, start: int, article: Article, articles: []Article) -> int {
	header := table_cells(lines[start])
	separator := table_cells(lines[start+1])
	if len(header) != len(separator) {
		fmt.panicf("%s has a table with mismatched columns", article.source_path)
	}

	fmt.sbprintfln(builder, `                            <div class="docs-table-wrapper">`)
	fmt.sbprintfln(builder, `                                <table class="docs-table">`)
	fmt.sbprintfln(builder, `                                    <thead><tr>`)
	for cell in header {
		fmt.sbprintfln(builder, `                                        <th scope="col">%s</th>`, render_inline_string(cell, article, articles))
	}
	fmt.sbprintfln(builder, `                                    </tr></thead>`)
	fmt.sbprintfln(builder, `                                    <tbody>`)

	i := start + 2
	for i < len(lines) && strings.trim_space(lines[i]) != "" && strings.index_byte(lines[i], '|') >= 0 {
		cells := table_cells(lines[i])
		if len(cells) != len(header) {
			fmt.panicf("%s has a table row with mismatched columns", article.source_path)
		}
		fmt.sbprintfln(builder, `                                        <tr>`)
		for cell, cell_index in cells {
			if cell_index == 0 {
				fmt.sbprintfln(builder, `                                            <th scope="row">%s</th>`, render_inline_string(cell, article, articles))
			} else {
				fmt.sbprintfln(builder, `                                            <td>%s</td>`, render_inline_string(cell, article, articles))
			}
		}
		fmt.sbprintfln(builder, `                                        </tr>`)
		i += 1
	}

	fmt.sbprintfln(builder, `                                    </tbody>`)
	fmt.sbprintfln(builder, `                                </table>`)
	fmt.sbprintfln(builder, `                            </div>`)
	return i
}

table_cells :: proc(line: string) -> []string {
	trimmed := strings.trim_space(line)
	if strings.has_prefix(trimmed, "|") {
		trimmed = trimmed[1:]
	}
	if strings.has_suffix(trimmed, "|") {
		trimmed = trimmed[:len(trimmed)-1]
	}
	parts := strings.split(trimmed, "|")
	for &part in parts {
		part = strings.trim_space(part)
	}
	return parts
}

list_item :: proc(line: string) -> (ordered: bool, text: string, ok: bool) {
	if len(line) >= 2 && (line[0] == '-' || line[0] == '*' || line[0] == '+') && line[1] == ' ' {
		return false, strings.trim_space(line[2:]), true
	}

	i := 0
	for i < len(line) && line[i] >= '0' && line[i] <= '9' {
		i += 1
	}
	if i > 0 && i+1 < len(line) && line[i] == '.' && line[i+1] == ' ' {
		return true, strings.trim_space(line[i+2:]), true
	}
	return false, "", false
}

render_list :: proc(builder: ^strings.Builder, lines: []string, start: int, article: Article, articles: []Article) -> int {
	ordered, _, _ := list_item(lines[start])
	if ordered {
		fmt.sbprintfln(builder, `                            <ol>`)
	} else {
		fmt.sbprintfln(builder, `                            <ul>`)
	}

	i := start
	for i < len(lines) {
		item_ordered, text, ok := list_item(lines[i])
		if !ok || item_ordered != ordered {
			break
		}
		fmt.sbprintfln(builder, `                                <li>%s</li>`, render_inline_string(text, article, articles))
		i += 1
	}

	if ordered {
		fmt.sbprintfln(builder, `                            </ol>`)
	} else {
		fmt.sbprintfln(builder, `                            </ul>`)
	}
	return i
}

is_horizontal_rule :: proc(line: string) -> bool {
	trimmed := strings.trim_space(line)
	if len(trimmed) < 3 {
		return false
	}
	marker := trimmed[0]
	if marker != '-' && marker != '*' && marker != '_' {
		return false
	}
	for c in transmute([]byte)trimmed {
		if c != marker && c != ' ' {
			return false
		}
	}
	return true
}

render_inline_string :: proc(text: string, article: Article, articles: []Article) -> string {
	builder := strings.builder_make()
	render_inline(&builder, text, article, articles)
	return strings.to_string(builder)
}

render_inline :: proc(builder: ^strings.Builder, text: string, article: Article, articles: []Article) {
	i := 0
	for i < len(text) {
		if text[i] == '`' {
			end := strings.index_byte(text[i+1:], '`')
			if end >= 0 {
				fmt.sbprintf(builder, "<code>%s</code>", escape_html(text[i+1:i+1+end]))
				i += end + 2
				continue
			}
		}

		if text[i] == '[' {
			close := strings.index_byte(text[i+1:], ']')
			if close >= 0 {
				close += i + 1
				if close+1 < len(text) && text[close+1] == '(' {
					end := strings.index_byte(text[close+2:], ')')
					if end >= 0 {
						end += close + 2
						label := text[i+1:close]
						target := strings.trim_space(text[close+2:end])
						fmt.sbprintf(builder, `<a href="%s">`, escape_html(resolve_link(article, target, articles)))
						render_inline(builder, label, article, articles)
						strings.write_string(builder, `</a>`)
						i = end + 1
						continue
					}
				}
			}
		}

		if strings.has_prefix(text[i:], "**") || strings.has_prefix(text[i:], "__") {
			marker := text[i:i+2]
			end := strings.index(text[i+2:], marker)
			if end >= 0 {
				end += i + 2
				strings.write_string(builder, `<strong>`)
				render_inline(builder, text[i+2:end], article, articles)
				strings.write_string(builder, `</strong>`)
				i = end + 2
				continue
			}
		}

		switch text[i] {
		case '&':
			strings.write_string(builder, `&amp;`)
		case '<':
			strings.write_string(builder, `&lt;`)
		case '>':
			strings.write_string(builder, `&gt;`)
		case '"':
			strings.write_string(builder, `&quot;`)
		case '\'':
			strings.write_string(builder, `&#39;`)
		case:
			strings.write_byte(builder, text[i])
		}
		i += 1
	}
}

resolve_link :: proc(article: Article, target: string, articles: []Article) -> string {
	lower_target, lower_err := strings.to_lower(target)
	if lower_err != nil {
		fmt.panicf("could not normalize link in %s: %v", article.source_path, lower_err)
	}
	if target == "" || target[0] == '#' || strings.has_prefix(lower_target, "http://") || strings.has_prefix(lower_target, "https://") || strings.has_prefix(lower_target, "mailto:") || strings.has_prefix(target, "//") || strings.has_prefix(target, "/") {
		return target
	}
	if strings.has_prefix(lower_target, "javascript:") || strings.has_prefix(lower_target, "data:") {
		fmt.panicf("%s contains a blocked link scheme: %s", article.source_path, target)
	}

	fragment := ""
	base := target
	if hash := strings.index_byte(target, '#'); hash >= 0 {
		base = target[:hash]
		fragment = target[hash:]
	}
	if strings.has_suffix(base, ".md") {
		directory, _ := slashpath.split(article.source_relative)
		candidate := slashpath.clean(fmt.aprintf("%s%s", directory, base))
		for other in articles {
			if other.source_relative == candidate {
				return fmt.aprintf("%s%s", other.route, fragment)
			}
		}
		fmt.panicf("%s links to missing article %s", article.source_path, target)
	}
	if strings.has_suffix(base, "lua_api.html") {
		return fmt.aprintf("/docs/lua_api.html%s", fragment)
	}
	return target
}

escape_html :: proc(text: string) -> string {
	builder := strings.builder_make()
	for c in transmute([]byte)text {
		switch c {
		case '&':
			strings.write_string(&builder, `&amp;`)
		case '<':
			strings.write_string(&builder, `&lt;`)
		case '>':
			strings.write_string(&builder, `&gt;`)
		case '"':
			strings.write_string(&builder, `&quot;`)
		case '\'':
			strings.write_string(&builder, `&#39;`)
		case:
			strings.write_byte(&builder, c)
		}
	}
	return strings.to_string(builder)
}
