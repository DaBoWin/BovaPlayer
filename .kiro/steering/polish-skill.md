---
inclusion: manual
---

# Polish Skill

Final quality pass before shipping. Fixes alignment, spacing, consistency, and detail issues that separate good from great.

## When to Use
Use this for final quality pass, fixing visual inconsistencies, improving interaction states, or preparing for launch.

**CRITICAL**: Polish is the last step, not the first. Don't polish work that's not functionally complete.

## Key Areas

### Visual Alignment & Spacing
- Pixel-perfect alignment to grid
- Consistent spacing using spacing scale (no random gaps)
- Optical alignment for visual weight
- Responsive consistency at all breakpoints

### Typography Refinement
- Hierarchy consistency
- Line length: 45-75 characters for body text
- Appropriate line height
- No widows & orphans
- Font loading: No FOUT/FOIT flashes

### Color & Contrast
- Contrast ratios meet WCAG standards
- Consistent token usage (no hard-coded colors)
- Theme consistency
- Accessible focus indicators
- Tinted neutrals (no pure gray/black)
- Gray on color: Use shade of that color, not gray

### Interaction States
Every interactive element needs:
- Default, Hover, Focus, Active, Disabled, Loading, Error, Success

### Micro-interactions & Transitions
- Smooth transitions (150-300ms)
- Consistent easing: ease-out-quart/quint/expo (never bounce or elastic)
- 60fps animations (only transform and opacity)
- Respects `prefers-reduced-motion`

### Content & Copy
- Consistent terminology and capitalization
- No typos
- Appropriate length
- Consistent punctuation

### Forms & Inputs
- All inputs properly labeled
- Clear required indicators
- Helpful error messages
- Logical tab order

### Edge Cases & Error States
- Loading, empty, error, success states
- Handles long content gracefully
- Appropriate offline handling

### Responsiveness
- Test mobile, tablet, desktop
- Touch targets: 44x44px minimum
- No text smaller than 14px on mobile
- No horizontal scroll

### Code Quality
- Remove console logs, commented code, unused imports
- Consistent naming
- Type safety (no TypeScript `any`)
- Proper ARIA labels and semantic HTML

## Polish Checklist
- Visual alignment perfect at all breakpoints
- Spacing uses design tokens consistently
- All interactive states implemented
- All transitions smooth (60fps)
- Copy is consistent and polished
- Touch targets are 44x44px minimum
- Contrast ratios meet WCAG AA
- Keyboard navigation works
- No console errors or warnings
- No layout shift on load
- Respects reduced motion preference

**NEVER**:
- Polish before functionally complete
- Introduce bugs while polishing
- Perfect one thing while leaving others rough
