# rainier (K17 CTF, osint)

The prompt asks us to identify where a rainy street photo was taken and format the answer as the two intersecting street names: `K17{street1,street2}` (case-insensitive, omitting road-type suffixes).

## Triangulating the intersection

Examining the EXIF metadata on `rainier.jpg` shows that all GPS coordinates and camera metadata were stripped prior to release. Everything has to come from visual cues:

1. **Building signage (left)**: Zooming in on the building on the left side reveals the sign `"NORTH BRIDGE CENTRE"`. North Bridge Centre is located at 420 North Bridge Road in Singapore, situated at the corner of North Bridge Road and Middle Road.
2. **Street signage (center)**: Visible across the intersection is a standard green Singapore Land Transport Authority (LTA) road sign reading `"Victoria St"`.
3. **Architecture (right)**: The large white structure with vertical louvres and a distinct curved facade matches the National Library Building at 100 Victoria Street.
4. **Traffic layout**: The median strip shows a U-turn permitted sign along a wide multi-lane divided road, consistent with Middle Road right beside the National Library.

These landmarks converge on the intersection of **Victoria Street** and **Middle Road** in Singapore. Submitting either `K17{Victoria,Middle}` or `K17{Middle,Victoria}` solves the challenge.

Flag: `K17{Victoria,Middle}`
