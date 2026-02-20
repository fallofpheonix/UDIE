# UDIE Risk Model Specification (v2)

UDIE treats the city as a continuous risk field approximation. This document defines the mathematical foundation for scoring.

## 1. Spatial Field Approximation
Risk is pre-aggregated into H3 hexagonal cells ($Res 9$). Each cell $c$ has a base weight $W_c$ derived from the active events within its radius.

## 2. Distance Decay (The Exponential Kernel)
The influence of a cell $c$ on a route point $P$ decays exponentially with distance $d$:
$$ I(P, c) = W_c \cdot e^{-d/\lambda} $$
- **Default $\lambda$**: $250.0m$ (Configurable in `model_parameters`).

## 3. Route Scoring
The raw risk score $R_{raw}$ for a route is the sum of influences from all neighboring risk cells:
$$ R_{raw} = \sum_{c \in Cells} I(P, c) $$

## 4. Sigmoid Normalization
The raw score is normalized into $[0, 1]$ using a sigmoid function:
$$ R_{norm} = 1 - e^{-R_{raw}/k} $$
- **Normalization Factor $k$**: $20.0$ (Configurable in `model_parameters`).
- **Interpretation**: 
  - $0.0 - 0.35$: **LOW**
  - $0.35 - 0.70$: **MEDIUM**
  - $0.70 - 1.0$: **HIGH**

## 5. Confidence Evolution (Temporal Decay)
Event confidence $C$ decays logarithmically with time $t$ in the absence of new reports:
$$ C_{t+1} = C_t \cdot \gamma $$
- **Decay Rate $\gamma$**: $0.97$ per 15m cycle.
- **Reinforcement**: New reports increase confidence via spatial-temporal deduplication logic.

---

## Invariants
- **Reproducibility**: Identical events + Identical parameters = Identical scores.
- **Boundedness**: Scores never exceed 1.0 regardless of report density.
