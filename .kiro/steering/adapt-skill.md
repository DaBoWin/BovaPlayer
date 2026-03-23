---
inclusion: manual
---

# Adapt Skill

Adapt designs to work across different screen sizes, devices, contexts, or platforms. Ensures consistent experience across varied environments.

## When to Use
Use this when adapting designs for mobile, tablet, desktop, print, email, or other contexts.

## Key Principles

### Assess Adaptation Challenge
1. Identify source context (what was it designed for?)
2. Understand target context (device, input method, screen constraints, connection, usage context)
3. Identify adaptation challenges (what won't fit, work, or is inappropriate)

**CRITICAL**: Adaptation is not just scaling - it's rethinking the experience for the new context.

### Mobile Adaptation (Desktop → Mobile)
- Single column layouts, vertical stacking
- Touch targets 44x44px minimum
- Progressive disclosure, prioritize primary content
- Bottom navigation or hamburger menu

### Tablet Adaptation
- Two-column layouts, master-detail views
- Support both touch and pointer
- Adaptive based on orientation

### Desktop Adaptation (Mobile → Desktop)
- Multi-column layouts, side navigation always visible
- Hover states, keyboard shortcuts, drag and drop
- Show more information upfront

### Responsive Breakpoints
- Mobile: 320px-767px
- Tablet: 768px-1023px
- Desktop: 1024px+

### Implementation
- Use CSS Grid/Flexbox, Container Queries
- Increase touch target sizes on mobile
- Progressive enhancement
- Test on real devices, not just DevTools

**NEVER**:
- Hide core functionality on mobile
- Use different information architecture across contexts
- Break user expectations for platform
- Ignore landscape orientation or touch on desktop
