
# UDIE Risk Model Specification (v2)

UDIE models urban disruption as a **time-evolving spatial field** discretized into H3 cells and evaluated against routes using bounded-cost kernels.

This document defines the mathematical behavior of that field.

---

## 1. Spatial Discretization

Continuous geography is partitioned into H3 hexagonal cells at a fixed resolution (default:  **Resolution 9** ).

Each cell cc**c** stores an aggregated weight:

Wc=∑e∈c(Se⋅Ce)W_c = \sum_{e \in c} (S_e \cdot C_e)**W**c=**e**∈**c**∑(**S**e⋅**C**e)
Where:

* SeS_e**S**e = severity of event ee**e**
* CeC_e**C**e = lifecycle-adjusted confidence of event ee**e**

This aggregation occurs during materialization and is not recomputed per request.

---

## 2. Distance-Based Influence Kernel

When evaluating a route, nearby cells influence the route proportionally to their distance.

For a route sample point PP**P** and cell cc**c**:

I(P,c)=Wc⋅e−d(P,c)/λI(P, c) = W_c \cdot e^{-d(P,c)/\lambda}**I**(**P**,**c**)**=**W**c****⋅**e**−**d**(**P**,**c**)**/**λ**
Where:

* d(P,c)d(P,c)**d**(**P**,**c**) = geodesic distance between PP**P** and the centroid of cell cc**c**
* λ\lambda**λ** = decay constant controlling spatial influence radius

### Default Parameter

λ=250 m\lambda = 250\,m**λ**=**250**m
This value is configurable via `model_parameters`.

---

## 3. Route Aggregation

The raw route risk is the accumulated influence of all intersecting or neighboring cells:

Rraw=∑P∈RouteSamples∑c∈NeighborCells(P)I(P,c)R_{raw} = \sum_{P \in RouteSamples} \sum_{c \in NeighborCells(P)} I(P, c)**R**r**a**w=**P**∈**R**o**u**t**e**S**am**pl**es**∑c**∈**N**e**i**g**hb**or**C**e**ll**s**(**P**)**∑I**(**P**,**c**)
Implementation uses:

* sampled route vertices mapped to H3 cells,
* bounded neighborhood lookup per sample.

This ensures evaluation complexity scales with:

<pre class="overflow-visible! px-0!" data-start="1732" data-end="1761"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>number_of_route_cells</span><span>
</span></span></code></div></div></pre>

and not with total events.

---

## 4. Normalization Function

To bound the score into a stable range, UDIE applies an exponential saturation function:

Rnorm=1−e−Rraw/kR_{norm} = 1 - e^{-R_{raw}/k}**R**n**or**m=**1**−**e**−**R**r**a**w****/**k**
Where:

* kk**k** = normalization constant controlling saturation speed.

### Default Parameter

k=20.0k = 20.0**k**=**20.0**
Stored in `model_parameters` to allow model tuning without redeploy.

---

## 5. Risk Classification Bands

The normalized score is mapped to discrete interpretation bands:

| Range        | Classification |
| ------------ | -------------- |
| 0.00 – 0.35 | LOW            |
| 0.35 – 0.70 | MEDIUM         |
| 0.70 – 1.00 | HIGH           |

These bands are interpretive only and must not affect computation.

---

## 6. Temporal Window Aggregation
UDIE has transitioned from a continuous decay model to a sliding temporal window (default: 6h).

Risk is computed as:
W = \sum_{e \in window} (S_e \cdot e^{-\gamma \cdot age})

This ensures stale disruptions fade naturally while maintaining lower compute overhead than per-event lifecycle management.

---

## 7. Spatial Density Amplification
To capture clustering effects where multiple disruptions reinforce each other, a density factor is applied during aggregation:

W_{final} = W \cdot (1 + \alpha \cdot \ln(1 + N))

Where:
* N = number of concurrent events in the cell or immediate neighborhood.
* \alpha = amplification factor (configurable in `model_parameters`).

---

## 8. Computational Guarantees

The model is designed to enforce the following:

### Bounded Evaluation

Risk computation depends on spatial sampling density, not dataset size.

---

### Stability Under Density Growth

Adding more historical observations does not increase request-time work, because aggregation collapses them into fixed cells.

---

### Saturation Safety

Normalization ensures:

0≤Rnorm<10 \le R_{norm} < 1**0**≤**R**n**or**m<**1**
regardless of report volume, preventing runaway scores.

---

## 8. Model Parameterization

All tunable values must reside in configuration storage:

* λ\lambda**λ** (spatial decay)
* kk**k** (normalization scale)
* γ\gamma**γ** (temporal decay)
* resolution (H3 level, if changed via versioning)

Hardcoding parameters violates reproducibility guarantees.

---

## Invariants

The following must always hold:

1. **Reproducibility**

   Identical inputs and parameters yield identical scores.
2. **Boundedness**

   Scores remain within [0,1)[0,1)**[**0**,**1**)**.
3. **Locality**

   Only spatially proximate cells influence a route.
4. **Temporal Convergence**

   Inactive disruptions decay toward zero influence.

---

## Summary

UDIE approximates the city as a discretized, decaying scalar field where:

* ingestion updates the field,
* lifecycle maintains temporal validity,
* materialization stabilizes computation,
* route evaluation samples the field efficiently.

The model deliberately trades geometric precision for deterministic scalability.
