# Feature candidate catalog

This catalog defines the evidence required for each candidate type. The implementation may support only a subset for a given topology; the API must expose warnings when evidence is incomplete.

## Hole

**Evidence:** inward-oriented cylindrical surface; one or more circular boundary edges; compatible axis/radius/projection; axial depth; termination evidence.

**Dimensions:** diameter, cylindrical depth, axis, projected centre, through/blind classification.

**Ambiguities:** an outer cylindrical boss has the same analytic surface but opposite boundary/orientation evidence. Split cylinder faces must be grouped. A through hole may be represented by multiple axial segments.

## Counterbore

**Evidence:** coaxial cylindrical wall with a larger diameter than the bore plus a planar annular shoulder terminating the smaller bore.

**Dimensions:** bore diameter, counterbore diameter, counterbore depth, shared axis.

**Ambiguities:** a shoulder between two coaxial bores can resemble a counterbore; direction and termination evidence must be retained.

## Countersink

**Evidence:** concave conical surface bounded by coaxial circles of different radii, associated with a bore, and a supported included angle where available.

**Dimensions:** top/bottom diameters, depth, angle, axis.

**Ambiguity:** a plain conical chamfer is not automatically a countersink.

## Slot

**Evidence:** an inward planar floor or cylindrical-ended cavity with two parallel boundary segments and semicircular/round termination evidence, or a concavity whose projected footprint is elongated.

**Dimensions:** overall length, width, depth, centre/orientation.

**Ambiguity:** a narrow rectangular pocket is geometrically similar to a slot; its classification should remain a candidate for review.

## Pocket/cavity

**Evidence:** inward planar floor bounded by connected walls and contained within the solid's outer boundary; relationship among floor, side walls, and opening.

**Dimensions:** footprint, depth, floor area, orientation.

**Ambiguity:** a step can share a planar face with a pocket; the supporting wall topology and containment relationship determine the candidate.

## Step/shoulder

**Evidence:** parallel planar faces at different axial positions connected by a perpendicular wall, with a measurable offset and material-removal side.

**Dimensions:** offset/height, affected footprint, axis, direction.

## Fillet

**Evidence:** toroidal surface with bounded radii and adjacency to two faces; concave/convex orientation.

**Dimensions:** radius, centre/tangent references, affected faces.

**Ambiguity:** a torus can represent another swept transition; adjacent face evidence is required.

## Chamfer

**Evidence:** narrow planar/conical transition between two faces with measurable angle/width and explicit adjacency.

**Dimensions:** width, angle, affected edges/faces.

**Ambiguity:** a conical countersink requires bore/coaxial evidence before that stronger label is used.

## Boss/rib

**Evidence:** outward protrusion with a supporting base face, connected side faces, and measurable projection. Ribs additionally require a thin elongated footprint.

**Dimensions:** projection, footprint, base area, orientation.

## Pattern

**Evidence:** multiple otherwise compatible candidates whose axes/centres fit a line, circle, row/column, or grid under an explicit tolerance.

**Dimensions:** count, spacing, pattern type, pitch, origin.

**Ambiguity:** pattern assignment never changes the underlying individual candidate confidence and must be reviewable.

## Thread candidate

A thread is assigned only when explicit drawing/text evidence supplies a thread designation and its association can be reviewed. A plain cylindrical hole is not labelled as tapped.
