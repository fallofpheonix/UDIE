# UDIE Design System (v1.1)

This document defines the **Design Tokens** and **Component Invariants** for the UDIE engine.

---

## 1. Design System Tokens (v1.1)

### 1.1 Typography Scale
Standardized type hierarchy using the **Outfit** font family for headers and **Inter** for body.

| Token | Size (px) | Weight | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `type.display` | 48px | 700 | 1.1 | Large metric focus. |
| `type.h1` | 32px | 600 | 1.2 | Section headers. |
| `type.h2` | 24px | 600 | 1.3 | Card titles. |
| `type.body.lg` | 18px | 400 | 1.5 | Primary reading. |
| `type.body` | 16px | 400 | 1.5 | Standard text. |
| `type.caption` | 12px | 500 | 1.4 | Secondary metadata. |
| `type.mono` | 14px | 400 | 1.5 | Agent code blocks (JetBrains Mono). |

### 1.2 Spacing System (4px Base)
All margins and padding must adhere to the 4px grid tokens.

| Token | Value | rem (16px base) | Usage |
| :--- | :--- | :--- | :--- |
| `space.xs` | 4px | 0.25rem | Micro-gap. |
| `space.sm` | 8px | 0.5rem | Internal padding. |
| `space.md` | 16px | 1.0rem | Standard padding. |
| `space.lg` | 24px | 1.5rem | Section spacing. |
| `space.xl` | 32px | 2.0rem | Canvas margins. |
| `space.2xl`| 48px | 3.0rem | Macro grouping. |

### 1.3 Color Palette (Functional)
| Token | Hex | Usage |
| :--- | :--- | :--- |
| `color.bg.primary` | `#0A0A0B` | Deep space background. |
| `color.surface.base` | `#1C1C1E` | Card/Container background. |
| `color.surface.elevated` | `#2C2C2E` | Hover/Active card states. |
| `color.text.primary` | `#FFFFFF` | Title and important text. |
| `color.text.muted` | `#8E8E93` | Telemetry and secondary text. |
| `color.status.critical` | `#FF3B30` | Disruption events/High risk. |
| `color.status.active` | `#007AFF` | Agent activity/Running sim. |
| `color.status.nominal` | `#34C759` | Healthy spatial cells. |
| `color.border` | `#3A3A3C` | Divider and edge highlights. |

---

## 2. Visual Identity

### Color Palette (Premium Dark Mode)
| Layer | Hex | Purpose |
| :--- | :--- | :--- |
| **Deep Space** | `#0A0A0B` | Primary background. |
| **Titanium** | `#1C1C1E` | Card backgrounds and containers. |
| **Pulse Red** | `#FF3B30` | Critical risk, disruption events. |
| **Cyber Blue** | `#007AFF` | Agent activity, tactical overlays. |
| **H3 Neon** | `#34C759` | Healthy spatial cells, low risk. |

### Typography
*   **Primary**: `Inter` (Variable) for high readability.
*   **Monospace**: `SF Mono` or `JetBrains Mono` for spatial coordinates and agent logs.

---

2. Optimize UI for the **most frequent actions**.
3. Every screen must have **one primary action**.
4. Reduce the number of steps required to complete tasks.
5. Eliminate unnecessary decisions.

### 2. Cognitive Load Control
6. Never show more than **7 actionable elements at once**.
7. Group related information visually.
8. Use progressive disclosure for complex systems.
9. Remove non-essential information.
10. Interfaces must be understandable in **under 3 seconds**.

### 3. Interaction Consistency
11. Identical actions must behave identically everywhere.
12. Button styles must represent specific actions.
13. Navigation patterns must never change between screens.
14. Keyboard shortcuts must remain consistent.
15. Component behavior must be predictable.

### 4. Layout Discipline
16. Use a strict grid system.
17. Maintain consistent spacing increments.
18. Align elements precisely.
19. Avoid arbitrary margins and padding.
20. Maintain visual hierarchy using size and contrast.

### 5. Speed and Responsiveness
21. Interaction feedback must occur in **under 100ms**.
22. Avoid blocking UI operations.
23. Use optimistic updates where possible.
24. Load critical UI elements first.
25. Prevent layout shifts.

### 6. Information Hierarchy
26. Important information must appear first.
27. Use typography hierarchy instead of color for importance.
28. Avoid deep navigation trees.
29. Use clear section boundaries.
30. Highlight actionable elements clearly.

### 7. Component Systems
31. Every UI element must come from a **component library**.
32. Components must support multiple states.
33. Components must behave identically across the product.
34. Avoid creating one-off UI elements.
35. Components must be composable.

### 8. Error Handling
36. Errors must explain **what happened and how to fix it**.
37. Prevent errors whenever possible.
38. Validate inputs before submission.
39. Never hide failure states.
40. Provide recovery paths.

### 9. Accessibility Discipline
41. Interfaces must work with keyboard navigation.
42. Ensure sufficient color contrast.
43. Provide focus indicators.
44. Avoid color-only communication.
45. Use semantic HTML elements.

### 10. Visual Minimalism
46. Remove visual noise.
47. Avoid unnecessary decoration.
48. Use color sparingly.
49. Use whitespace intentionally.
50. Visual design must support functionality, not replace it.

---

## 8. Advanced UI/UX Engineering Rules (60 Principles)

Deeper engineering principles used to build world-class UI/UX systems.

### 1. Interaction Architecture
1. Design interactions before visual styling.
2. Every UI action must have a predictable outcome.
3. User actions must always produce feedback.
4. Avoid hidden interactions unless they are expert shortcuts.
5. Important actions must be visible without exploration.
6. Destructive actions must require confirmation.
7. Reversible actions reduce user anxiety.
8. Multi-step workflows must show progress indicators.

### 2. Navigation Architecture
9. Navigation must remain consistent across the entire product.
10. Primary navigation should contain **5–7 items maximum**.
11. Secondary navigation must be visually separated.
12. Avoid nested navigation deeper than 3 levels.
13. Navigation labels must use user terminology.
14. Users must always know **where they are in the system**.
15. Provide shortcuts to common sections.

### 3. Data Visualization
16. Visualizations must emphasize patterns, not decoration.
17. Avoid unnecessary chart complexity.
18. Labels must always accompany charts.
19. Color usage in charts must represent meaning.
20. Default views should show the most relevant information.
21. Interactive filtering must be immediate.

### 4. Form Engineering
22. Reduce form fields to the minimum required.
23. Group related fields logically.
24. Use inline validation.
25. Display validation errors near the input field.
26. Autofill and autocomplete whenever possible.
27. Preserve user input during errors.

### 5. Feedback and System Status
28. Systems must always communicate their status.
29. Use progress indicators for long tasks.
30. Display loading states immediately.
31. Avoid blank screens.
32. Provide retry mechanisms when failures occur.
33. Show timestamps for dynamic data.

### 6. Motion and Animation
34. Motion should explain state changes.
35. Animations must remain under **300ms**.
36. Avoid excessive motion.
37. Use animation to guide user attention.
38. Ensure animations never block interactions.

### 7. Performance UX
39. Perceived speed matters more than absolute speed.
40. Load visible content first.
41. Use skeleton screens instead of spinners when possible.
42. Defer non-critical content loading.
43. Cache frequently accessed data.
44. Avoid UI jank during updates.

### 8. Mobile Interface Design
45. Design touch targets at least **44px** in size.
46. Place primary actions within thumb reach.
47. Avoid hover-dependent interactions.
48. Optimize layouts for vertical scrolling.
49. Minimize text input on mobile.

### 9. Design System Discipline
50. Maintain a centralized design token system.
51. Version the design system.
52. Maintain component documentation.
53. Enforce component reuse across teams.
54. Test components for accessibility and responsiveness.

### 10. UX Evaluation Metrics
55. Measure **task completion rate**.
56. Track **user error frequency**.
57. Measure **time to complete tasks**.
58. Analyze navigation patterns.
59. Monitor feature adoption rates.
60. Use usability testing to validate assumptions.

---

## 9. Catastrophic UI/UX Mistakes (100 Failures)

Severe engineering failures that destroy product usability. Avoid these at all costs.

### 1. Information Architecture Failures
1. No clear navigation hierarchy.
2. Too many primary navigation items.
3. Deep nested menus beyond 3 levels.
4. Inconsistent navigation structure between pages.
5. Duplicate navigation paths for the same content.
6. Ambiguous section labels.
7. Mixing unrelated features in one section.
8. Overloaded dashboards showing excessive data.
9. Important features hidden in settings menus.
10. Users cannot determine their current location in the interface.

### 2. Interaction Design Failures
11. Buttons that do not look clickable.
12. Clickable elements that look like static text.
13. Inconsistent interaction behavior.
14. Hidden critical actions.
15. Actions requiring excessive steps.
16. No confirmation for destructive actions.
17. Irreversible destructive operations.
18. Unexpected system behavior after user actions.
19. Interfaces requiring memorization instead of recognition.
20. Unclear interaction affordances.

### 3. Visual Hierarchy Failures
21. No clear visual hierarchy.
22. Overuse of bold colors.
23. Excessive typography variations.
24. Important elements visually indistinguishable.
25. Cluttered screens with no whitespace.
26. Arbitrary spacing between elements.
27. Inconsistent layout alignment.
28. Decorative elements distracting from functionality.
29. Excessive visual noise.
30. No separation between sections.

### 4. Form and Input Failures
31. Forms with excessive required fields.
32. Poor field grouping.
33. No input validation until submission.
34. Validation messages far from input fields.
35. Losing user input after submission errors.
36. Poor placeholder usage replacing labels.
37. Inconsistent form layouts.
38. No autocomplete or autofill support.
39. Confusing error messages.
40. Mandatory fields not clearly indicated.

### 5. Feedback and System Status Failures
41. No feedback after user actions.
42. No loading indicators.
43. Long operations without progress indicators.
44. Silent failures.
45. Vague error messages.
46. Error messages blaming the user.
47. Inconsistent system messages.
48. UI freezing during operations.
49. No confirmation after successful actions.
50. No retry options for failed actions.

### 6. Performance UX Failures
51. Slow page loads without feedback.
52. UI blocking during data fetching.
53. Layout shifts during loading.
54. Excessive animations slowing interactions.
55. Unoptimized image assets.
56. Large JavaScript bundles.
57. Frequent full page reloads.
58. Excessive API calls from UI.
59. Re-rendering large components unnecessarily.
60. Slow filtering and search operations.

### 7. Mobile UX Failures
61. Small touch targets.
62. Buttons too close together.
63. Interfaces designed only for desktop.
64. Horizontal scrolling required.
65. Hover-based interactions on mobile.
66. Long forms difficult to complete on mobile.
67. Content clipped on small screens.
68. Fixed elements blocking content.
69. Slow mobile performance.
70. Poor keyboard handling.

### 8. Accessibility Failures
71. Low contrast text.
72. Missing focus indicators.
73. No keyboard navigation support.
74. Missing semantic HTML structure.
75. Screen reader incompatibility.
76. Color-only information communication.
77. Missing alt text for images.
78. Clear interactions inaccessible via keyboard.
79. Poor form labeling.
80. Motion animations causing accessibility issues.

### 9. Design System Failures
81. No centralized component library.
82. Multiple versions of the same component.
83. Inconsistent spacing systems.
84. Different UI styles across pages.
85. Unmanaged design tokens.
86. Components behaving differently across contexts.
87. One-off UI components.
88. No design system documentation.
89. Poor version control of components.
90. Designers and developers using different design standards.

### 10. Product-Level UX Failures
91. Feature overload with no prioritization.
92. No onboarding experience.
93. Users unable to discover key features.
94. Poor search functionality.
95. No shortcuts for power users.
96. No personalization options.
97. Confusing pricing and upgrade flows.
98. Poor error recovery paths.
99. Interfaces requiring training to use.
100. Design decisions driven by aesthetics instead of usability.

### 11. Final Assessment Invariants
High quality UI/UX systems require coordination between product design, frontend engineering, and user research. Without systematic discipline, interfaces gradually degrade into inconsistent and unusable systems.

---

## 10. Frontend Engineering Failures (120 Mistakes)

Critical frontend engineering failures that make UI systems slow, unstable, or unreliable.

### 1. Rendering Architecture Failures
1. Rendering large component trees unnecessarily.
2. Missing memoization for expensive components.
3. Re-rendering entire pages for small state updates.
4. Using global state for local UI data.
5. Deep component nesting.
6. Passing large objects through props repeatedly.
7. Uncontrolled component re-renders.
8. Improper use of reactive state updates.
9. Creating new objects in render cycles.
10. Rendering huge lists without virtualization.

### 2. State Management Failures
11. Storing server data in UI state incorrectly.
12. Duplicating state across components.
13. Mutating state directly.
14. Uncontrolled global state growth.
15. Mixing UI state with application state.
16. No state normalization for large datasets.
17. Excessive state updates causing render loops.
18. Improper state dependency tracking.
19. Complex state structures difficult to maintain.
20. Lack of state isolation between modules.

### 3. Component Architecture Failures
21. Large “god components” managing too many responsibilities.
22. Business logic inside UI components.
23. No separation between view and logic.
24. Duplicate component implementations.
25. Components tightly coupled with backend APIs.
26. Components not reusable.
27. Overuse of context providers.
28. Improper component abstraction.
29. Inconsistent component naming conventions.
30. Hardcoded UI behavior.

### 4. Performance Failures
31. Large JavaScript bundles.
32. No code splitting.
33. Loading entire application on initial load.
34. Blocking main thread with heavy computations.
35. Inefficient DOM updates.
36. Frequent layout recalculations.
37. Inefficient animation techniques.
38. Reflow-triggering CSS properties.
39. Rendering unnecessary hidden components.
40. Excessive image sizes.

### 5. Network and Data Fetching Failures
41. Multiple duplicate API requests.
42. No caching strategy.
43. Sequential API calls instead of parallel requests.
44. No request deduplication.
45. Poor error handling for network failures.
46. No retry mechanisms.
47. Large payload responses.
48. Unnecessary polling instead of event-based updates.
49. Fetching unused data fields.
50. Unoptimized GraphQL queries.

### 6. Async and Concurrency Failures
51. Race conditions in async requests.
52. Out-of-order response handling.
53. State updates after component unmount.
54. Memory leaks from unfinished promises.
55. No request cancellation.
56. Blocking UI during async operations.
57. Unhandled promise rejections.
58. Improper async error propagation.
59. Infinite request retry loops.
60. Poor loading state management.

### 7. Browser Behavior Failures
61. Ignoring browser rendering pipelines.
62. Frequent layout thrashing.
63. Unoptimized DOM queries.
64. Excessive event listeners.
65. Heavy synchronous JavaScript execution.
66. Inefficient CSS selectors.
67. Excessive DOM nodes.
68. Blocking scripts during page load.
69. Inefficient scroll event handling.
70. Poor handling of resize events.

### 8. Asset Management Failures
71. Uncompressed images.
72. Loading large assets unnecessarily.
73. No lazy loading for media.
74. No asset caching.
75. Missing CDN usage.
76. Poor font loading strategy.
77. Too many font weights.
78. Unoptimized SVG assets.
79. No asset bundling strategy.
80. Loading unused libraries.

### 1. Security Failures
81. XSS vulnerabilities through unsanitized input.
82. Rendering unescaped HTML content.
83. Storing tokens insecurely.
84. Exposing API keys in frontend code.
85. Improper CORS configurations.
86. Missing CSRF protections.
87. Sensitive data exposed in browser storage.
88. Debug information exposed in production builds.
89. Insecure cookie handling.
90. Unprotected authentication flows.

### 10. Design System Integration Failures
91. Inconsistent component styling.
92. Hardcoded colors and spacing.
93. Multiple styling approaches within the same app.
94. Inconsistent UI components across pages.
95. Poorly maintained component libraries.
96. Lack of shared design tokens.
97. Missing documentation for components.
98. UI elements implemented differently by teams.
99. Duplicate design patterns.
100. Ignoring accessibility guidelines.

### 11. Mobile Performance Failures
101. Desktop-first design causing poor mobile performance.
102. Large bundle sizes affecting mobile loading.
103. Heavy animations on low-end devices.
104. Inefficient touch event handling.
105. Excessive DOM complexity on mobile screens.
106. Unoptimized viewport configurations.
107. Large images on mobile networks.
108. No adaptive loading strategies.
109. Heavy client-side rendering on mobile devices.
110. Slow keyboard input responses.

### 12. Observability and Debugging Failures
111. No performance monitoring.
112. No error tracking in production.
113. Lack of logging for frontend failures.
114. No user session monitoring.
115. Missing analytics on user flows.
116. No monitoring of API performance from UI.
117. Ignoring browser performance tools.
118. Lack of structured error reporting.
119. No alerting for production UI failures.
120. No continuous UX performance testing.
