---
inclusion: manual
---

# Optimize Skill

Improve interface performance across loading speed, rendering, animations, images, and bundle size. Makes experiences faster and smoother.

## When to Use
Use this when improving performance, reducing load times, optimizing bundle size, or fixing rendering issues.

## Key Principles

**CRITICAL**: Measure before and after. Premature optimization wastes time. Optimize what actually matters.

### Loading Performance

**Optimize Images**:
- Use modern formats (WebP, AVIF)
- Proper sizing, lazy loading, responsive images
- Compress (80-85% quality)
- Use CDN

**Reduce JavaScript Bundle**:
- Code splitting (route-based, component-based)
- Tree shaking, remove unused dependencies
- Lazy load non-critical code

**Optimize CSS & Fonts**:
- Remove unused CSS, critical CSS inline
- Use `font-display: swap`, subset fonts
- Limit font weights loaded

### Rendering Performance

**Avoid Layout Thrashing**:
- Batch reads, then batch writes
- Don't alternate DOM reads and writes

**Optimize Rendering**:
- Use CSS `contain` property
- Minimize DOM depth and size
- Use `content-visibility: auto` for long lists
- Virtual scrolling for very long lists

**Reduce Paint & Composite**:
- Use `transform` and `opacity` for animations (GPU-accelerated)
- Avoid animating layout properties (width, height, top, left)
- Use `will-change` sparingly

### Animation Performance
- Target 16ms per frame (60fps)
- Use `requestAnimationFrame` for JS animations
- Use CSS animations when possible
- Debounce/throttle scroll handlers

### React/Framework Optimization
- Use `memo()`, `useMemo()`, `useCallback()`
- Virtualize long lists
- Code split routes
- Minimize re-renders

### Core Web Vitals
- **LCP < 2.5s**: Optimize hero images, inline critical CSS, use CDN
- **FID < 100ms / INP < 200ms**: Break up long tasks, defer non-critical JS
- **CLS < 0.1**: Set dimensions on images, use `aspect-ratio`, reserve space

### Performance Monitoring
- Chrome DevTools (Lighthouse, Performance panel)
- WebPageTest, Core Web Vitals
- Bundle analyzers
- Test on real devices with real network conditions

**NEVER**:
- Optimize without measuring
- Sacrifice accessibility for performance
- Use `will-change` everywhere
- Lazy load above-fold content
- Forget about mobile performance
