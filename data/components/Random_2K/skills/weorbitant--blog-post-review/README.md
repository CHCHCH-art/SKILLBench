# Blog Post Review

Editorial review skill for the Orbitant engineering blog.

## What It Does

Provides structured feedback on blog article drafts, covering:
- SEO optimization (title, meta description, headings, links)
- Content quality and depth
- Tone and style alignment with Orbitant guidelines
- Actionable improvement suggestions

## Usage

Ask Claude to review a blog post:

```
Review this blog post draft for the Orbitant engineering blog:
[paste article content]
```

Or reference a file:

```
Review the blog post in /content/posts/my-article.md
```

## Output

The skill produces a structured review with:
1. Overall impression (strengths first)
2. Target audience analysis
3. Content depth assessment
4. SEO checklist with pass/fail markers
5. Editorial alignment review
6. Top 3-5 ranked actionable suggestions

## Language Support

Reviews are provided in the same language as the article:
- `lang: en` in frontmatter → English review
- `lang: es` in frontmatter → Spanish review
