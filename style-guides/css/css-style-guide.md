# CSS Style Guide

This document outlines the coding standards and best practices for CSS and SCSS development within this project. Adhering to these guidelines ensures code consistency, maintainability, scalability, and performance.

## Table of Contents

1. [General Principles](#general-principles)
2. [Formatting and Layout](#formatting-and-layout)
3. [Naming Conventions](#naming-conventions)
4. [Syntax and Selectors](#syntax-and-selectors)
5. [Units and Values](#units-and-values)
6. [Sass/SCSS Guidelines](#sassscss-guidelines)
7. [Architecture](#architecture)
8. [Responsive Design](#responsive-design)
9. [Performance](#performance)
10. [Accessibility](#accessibility)
11. [Browser Support](#browser-support)
12. [Recommended Tools](#recommended-tools)

## General Principles

- **Separation of Concerns**: Keep structure (HTML), presentation (CSS), and behavior (JavaScript) separate.
- **DRY (Don't Repeat Yourself)**: Use classes and mixins to reuse styles. Avoid copy-pasting code blocks.
- **Predictability**: Styles should behave consistently. Avoid complex specificity wars.
- **Maintainability**: Write code that is easy to understand and modify by others.
- **Scalability**: Use methodologies (like BEM) that allow the project to grow without style conflicts.

## Formatting and Layout

- **Indentation**: Use 2 spaces for indentation. Do not use tabs.
- **Line Length**: Limit lines to 80 characters where possible, though CSS often requires longer lines.
- **Brace Placement**:
    - Opening brace `{` on the same line as the selector, preceded by a space.
    - Closing brace `}` on a new line, aligned with the start of the selector.
- **Spacing**:
    - Put a space after the colon in property declarations (e.g., `color: red;`).
    - Put a space before the opening brace.
    - Put a blank line between rule sets.
- **Quotes**: Use double quotes `"` for attribute selectors and URL values (e.g., `content: "";`, `url("image.png")`).

```css
/* Good */
.selector,
.selector-secondary {
  display: block;
  width: 100%;
}

/* Bad */
.selector {display:block;width:100%}
```

## Naming Conventions

- **BEM (Block Element Modifier)**: Use the BEM naming convention to create self-documenting, reusable components.
    - **Block**: `.block` (e.g., `.card`)
    - **Element**: `.block__element` (e.g., `.card__title`)
    - **Modifier**: `.block--modifier` or `.block__element--modifier` (e.g., `.card--featured`, `.card__title--large`)
- **Case**: Use `kebab-case` for all class names and IDs (e.g., `.main-header`, `#submit-button`).
- **IDs**: Avoid using IDs for styling. They have high specificity and are hard to override. Use classes instead. IDs should be reserved for JavaScript hooks or anchor links.
- **JavaScript Hooks**: Use specific classes prefixed with `js-` for JavaScript bindings to separate styling from behavior (e.g., `.js-toggle-menu`). Do not style these classes.

```css
/* BEM Example */
.nav-bar { ... }
.nav-bar__item { ... }
.nav-bar__item--active { ... }
```

## Syntax and Selectors

- **Specificity**: Keep specificity as low as possible. Avoid using `!important` unless absolutely necessary (e.g., overriding 3rd party inline styles).
- **Nesting**: Avoid nesting selectors deeper than 3 levels. Deep nesting increases specificity and file size, and reduces performance.
- **Type Selectors**: Avoid qualifying classes with type selectors (e.g., `div.container`). It unnecessarily increases specificity.
- **Shorthand Properties**: Use shorthand properties (e.g., `margin`, `padding`, `font`) with caution. explicit longhand properties are often safer to avoid resetting unwanted values.
- **Zero Values**: Do not specify units for zero values (e.g., `margin: 0;` not `margin: 0px;`).

```css
/* Good */
.sidebar { ... }

/* Bad - overly specific */
body #container div.sidebar { ... }
```

## Units and Values

- **Relative Units**: Prefer relative units (`rem`, `em`, `%`) over absolute units (`px`) for layout, sizing, and typography to support accessibility and responsiveness.
    - Use `rem` for font sizes and spacing to respect the user's browser font size settings.
    - Use `em` for component-relative sizing.
- **Colors**:
    - Use hex codes (`#ffffff`) or `rgb()`/`rgba()`.
    - Use lowercase for hex codes.
    - Use shorthand hex codes where possible (e.g., `#fff` instead of `#ffffff`).
- **Floating Numbers**: Omit the leading zero for floating-point numbers less than 1 (e.g., `.5` instead of `0.5`).

## Sass/SCSS Guidelines

- **Syntax**: Use SCSS syntax (`.scss`), not the older indented syntax (`.sass`).
- **Variables**: Use variables for colors, fonts, z-indices, and spacing.
- **Nesting**: Stick to the 3-level nesting rule. Just because you *can* nest deeply doesn't mean you *should*.
- **Ampersand (`&`)**: Use the parent selector `&` for pseudo-classes (`&:hover`) and BEM modifiers (`&--active`), but avoid using it to concatenate strings to form class names (e.g., `&__element`) as it makes searching the codebase harder.
- **Mixins**: Use mixins for groups of properties or complex vendor prefixing (if Autoprefixer is not used).
- **Extend**: Avoid `@extend`. It can lead to bloated CSS and unexpected selector grouping. Use mixins instead.
- **Comments**:
    - Use `//` for comments that shouldn't appear in the compiled CSS.
    - Use `/* ... */` for comments that should be preserved (e.g., copyright headers).

```scss
/* Good */
.btn {
  background-color: $color-primary;

  &:hover {
    background-color: darken($color-primary, 10%);
  }
}
```

## Architecture

- **7-1 Pattern**: Adopt a modular architecture like the 7-1 pattern:
    - `base/`: Boilerplate code (reset, typography).
    - `components/`: Specific UI components (buttons, carousel).
    - `layout/`: Macro layout (header, footer, grid).
    - `pages/`: Page-specific styles.
    - `themes/`: Theme-specific styles (dark mode).
    - `abstracts/`: Variables, mixins, functions (no output).
    - `vendors/`: Third-party CSS (Bootstrap, jQuery UI).
    - `main.scss`: The main entry point that imports all other files.

## Responsive Design

- **Mobile-First**: Write styles for mobile devices first, then use `min-width` media queries to override styles for larger screens.
- **Breakpoints**: Use standard breakpoints or define them as variables. Avoid magic numbers.
- **Media Queries**: Nest media queries inside the selector they modify for better locality of code, or keep them in separate layout files if using a grid system.

```scss
.element {
  width: 100%;

  @media (min-width: 768px) {
    width: 50%;
  }
}
```

## Performance

- **Minification**: Always minify CSS for production.
- **Critical CSS**: Inline critical CSS (styles required for above-the-fold content) to improve First Contentful Paint (FCP).
- **Animations**: Prefer `transform` and `opacity` for animations as they are handled by the GPU and don't trigger repaints/reflows.
- **Selector Performance**: Avoid expensive selectors like `*` (universal selector) or regex attribute selectors (`[class^="..."]`) in performance-critical areas.

## Accessibility

- **Focus Styles**: Never remove outline on focus (`outline: none`) without providing an alternative style. Keyboard users rely on focus indicators.
- **Hidden Content**: Use a robust "visually-hidden" utility class to hide content from visual users but keep it available to screen readers, rather than `display: none` or `visibility: hidden`.
- **Contrast**: Ensure sufficient color contrast between text and background (WCAG AA standard).
- **Reduced Motion**: Respect the user's `prefers-reduced-motion` setting.

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

## Browser Support

- **Autoprefixer**: Use Autoprefixer to automatically add vendor prefixes based on supported browser versions. Do not write vendor prefixes manually.
- **Fallbacks**: Provide fallback values for newer CSS features (e.g., CSS Grid, Custom Properties) for older browsers.

## Recommended Tools

- **Linter**: `stylelint` for enforcing CSS/SCSS standards.
- **Formatter**: `Prettier` for consistent code formatting.
- **Post-processor**: `PostCSS` with `Autoprefixer`.
- **Methodology**: BEM or SMACSS.
