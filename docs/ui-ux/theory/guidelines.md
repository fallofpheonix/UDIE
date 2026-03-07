# UDIE UI/UX Guidelines (v1.0)

This document defines the **design discipline** required to produce high-quality UI/UX systems for UDIE.

---

## 1. Interaction Pipeline
All interface work must follow this pipeline:
`Problem Definition` → `User Task Analysis` → `Information Architecture` → `Interaction Model` → `Wireframes` → `Visual System` → `Prototype` → `Usability Testing` → `Implementation`.

## 2. Information Architecture Rules
*   **Max 3 Levels**: Deep nesting destroys mental models.
*   **Logical Grouping**: Group spatial metrics, agent status, and simulation controls separately.
*   **Consistent Labeling**: Use "Disruption" for active events and "Anomaly" for projected risks.

## 3. Interaction Mechanics
*   **Predictable Outcomes**: Identical actions must behave identically everywhere.
*   **Reversibility**: Destructive actions (e.g. clearing a simulation) must require confirmation and have a 5-second "Undo" window.
*   **Feedback**: Any system change must provide visual feedback in under 100ms.
