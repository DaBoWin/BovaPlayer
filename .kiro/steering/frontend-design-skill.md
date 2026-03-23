---
inclusion: manual
---

# Frontend Design Skill

Create distinctive, production-grade frontend interfaces with high design quality. Avoid generic AI aesthetics.

## When to Use
Use this when building web components, pages, applications, or any frontend interface that needs exceptional design quality.

## Design Direction

Commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this solve? Who uses it?
- **Tone**: Pick an extreme (brutally minimal, maximalist, retro-futuristic, organic, luxury, playful, editorial, brutalist, art deco, soft/pastel, industrial, etc.)
- **Differentiation**: What makes this UNFORGETTABLE?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work—the key is intentionality.

## Key Guidelines

### Typography
- Use beautiful, unique fonts (NOT Inter, Roboto, Arial, Open Sans)
- Modular type scale with fluid sizing (clamp)
- Vary font weights and sizes for hierarchy
- DON'T use monospace as lazy "technical" shorthand
- DON'T put large rounded icons above every heading

### Color & Theme
- Use modern CSS (oklch, color-mix, light-dark)
- Tint neutrals toward brand hue
- DON'T use gray text on colored backgrounds (use shade of background color)
- DON'T use pure black (#000) or pure white (#fff)
- DON'T use AI color palette: cyan-on-dark, purple-to-blue gradients, neon accents
- DON'T use gradient text for "impact"
- DON'T default to dark mode with glowing accents

### Layout & Space
- Create visual rhythm through varied spacing
- Use fluid spacing with clamp()
- Use asymmetry and unexpected compositions
- DON'T wrap everything in cards
- DON'T nest cards inside cards
- DON'T use identical card grids
- DON'T center everything
- DON'T use same spacing everywhere

### Visual Details
- Use intentional, purposeful decorative elements
- DON'T use glassmorphism everywhere
- DON'T use rounded elements with thick colored border on one side
- DON'T use sparklines as decoration
- DON'T use rounded rectangles with generic drop shadows
- DON'T use modals unless truly necessary

### Motion
- Use motion for state changes
- Use exponential easing (ease-out-quart/quint/expo)
- For height animations, use grid-template-rows transitions
- DON'T animate layout properties (use transform and opacity only)
- DON'T use bounce or elastic easing

### Interaction
- Use progressive disclosure
- Design empty states that teach
- Make every interactive surface intentional
- DON'T repeat the same information
- DON'T make every button primary

### Responsive
- Use container queries (@container)
- Adapt for different contexts
- DON'T hide critical functionality on mobile

## The AI Slop Test

If someone saw this and immediately thought "AI made this," that's the problem. A distinctive interface should make someone ask "how was this made?" not "which AI made this?"

Review the DON'T guidelines—they are fingerprints of AI-generated work from 2024-2025.

## Implementation

Match implementation complexity to aesthetic vision. Interpret creatively and make unexpected choices. No design should be the same. Vary between light/dark themes, different fonts, different aesthetics. NEVER converge on common choices.
