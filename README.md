
<div align="center">
    <a href="">
        <img src="https://user-images.githubusercontent.com/33347703/97248564-f9318600-17f9-11eb-83b7-238c6aa7a4e8.png" alt="LightningBeams" height="100" />
    </a>
</div>

<hr />

Optimised, lightweight, and highly customisable Lightning Effects for use in Roblox. Can be made into all sorts of special effects.

**Features:**

 - Layered, moving Perlin noise
 - Uniform disk-point picking for even distribution of control points
 - Can go along a Bezier curve rather than just straight-lines (i.e. Similar to how rblx beams curve)
 - Varying thickness, length, and, transparency
 - Can use ColorSequences
 - Lightning "Sparks" and "Explosion" sub-modules
 - Can smoothly travel as a projectile trying to reach a point

Table of contents
=============

<!--ts-->
   * [Table of contents](#table-of-contents)
   * [Showcase](#showcase)
   * [Usage](#usage)
      * [LightningBolt](#lightningbolt)
      * [LightningSparks](#lightningsparks)
      * [LightningExplosion](#lightningexplosion)
   * [Downloads](#downloads)
<!--te-->

Showcase
========

![ezgif com-gif-maker](https://user-images.githubusercontent.com/33347703/97609540-a3ccc300-1a0b-11eb-9b9a-a946163ed356.gif)
![ezgif com-gif-maker (2)](https://user-images.githubusercontent.com/33347703/97610440-c3b0b680-1a0c-11eb-8c1b-f5f423ab0168.gif)
![ezgif com-gif-maker (4)](https://user-images.githubusercontent.com/33347703/97610571-fb1f6300-1a0c-11eb-8db4-0138d1ff25ff.gif)

Usage
=====

This section shows the entire API for the main module (**LightningBolt**) and sub-modules (**LightningSparks**, **LightningExplosion**). Default values for properties are in the code.

Example
```
local LightningBolt = require((...).LightningBolt)
--Create a new bolt with 40 parts
local NewBolt = LightningBolt.new(workspace.Attach0, workspace.Attach1, 40)
--Then, update properties to your liking
NewBolt.CurveSize0, NewBolt.CurveSize1 = 10, 15
NewBolt.PulseSpeed = 2
NewBolt.PulseLength = 0.5
NewBolt.FadeLength = 0.25
NewBolt.MaxRadius = 1
NewBolt.Color = Color3.new(math.random(), math.random(), math.random())
local NewSparks = LightningSparks.new(NewBolt)
```

LightningBolt
-------------

``LightningBolt.new(Attachment0, Attachment1, PartCount)``\
Creates a bolt at source *Attachment0* which flows into sink *Attachment1* with number of parts *PartCount*

``LightningBolt:Destroy()``\
Cleans up and clears from memory

**Appearance Properties**

``Enabled``\
Hides bolt without destroying any parts when false\
``Attachment0, Attachment1``\
Bolt originates from Attachment0 and ends at Attachment1\
``CurveSize0, CurveSize1``\
Works similarly to beams. See https://dk135eecbplh9.cloudfront.net/assets/blt160ad3fdeadd4ff2/BeamCurve1.png \
``MinRadius, MaxRadius``\
Governs the amplitude of fluctuations throughout the bolt\
``Frequency``\
Governs the frequency of fluctuations throughout the bolt. Lower this to remove jittery-looking lightning\
``AnimationSpeed``\
Governs how fast the bolt oscillates (i.e. how fast the fluctuating wave travels along bolt)\
``Thickness``\
The thickness of the bolt\
``MinThicknessMultiplier, MaxThicknessMultiplier``\
Multiplies Thickness value by a fluctuating random value between MinThicknessMultiplier and MaxThicknessMultiplier along the Bolt

**Kinetic Properties**

 - Allows for fading in (or out) of the bolt with time. Can also create a "projectile" bolt
 - Recommend setting AnimationSpeed to 0 if used as projectile (for better aesthetics)
 - Works by passing a "wave" function which travels from left to right where the wave height represents opacity (opacity being 1 - Transparency)
 - See https://www.desmos.com/calculator/hg5h4fpfim to help customise the shape of the wave with the below properties:

``MinTransparency, MaxTransparency``\
See https://www.desmos.com/calculator/hg5h4fpfim \
``PulseSpeed``\
Bolt arrives at Attachment1 1/PulseSpeed seconds later. See https://www.desmos.com/calculator/hg5h4fpfim \
``PulseLength``\
See https://www.desmos.com/calculator/hg5h4fpfim \
``FadeLength``\
See https://www.desmos.com/calculator/hg5h4fpfim \
``ContractFrom``\
Parts shorten or grow once their Transparency exceeds this value. Set to a value above 1 to turn effect off. See https://imgur.com/OChA441

**Color Properties**

``Color``\
Can be a Color3 or ColorSequence\
``ColorOffsetSpeed``\
Sets speed at which ColorSequence travels along Bolt

LightningSparks
---------------

``LightningSparks.new(LightningBolt, MaxSparkCount)``\
Creates Lightning Sparks which fly out from *LightningBolt* up to a maximum of *MaxSparkCount*

``LightningSparks:Destroy()``\
Clears from memory

**Properties**

``Enabled``\
Stops spawning sparks when false\
``LightningBolt``\
Bolt which sparks fly out of\
``MaxSparkCount``\
Max number of sparks visible at any given instance\
``MinSpeed, MaxSpeed``\
Min and max PulseSpeeds of sparks\
``MinDistance, MaxDistance``\
Governs how far sparks travel away from main bolt\
``MinPartsPerSpark, MaxPartsPerSpark``\
Adjustable

LightningExplosion
------------------

``LightningExplosion.new(Position, Size, NumBolts, Color, BoltColor, UpVector)``\
*Size*: Value between 0 and 1 (1 for largest)\
*NumBolts*: Number of lightning bolts shot out from explosion\
*Color*: Can be a Color3 or ColorSequence\
*BoltColor*: Can be a Color3 or ColorSequence\
*UpVector*: Can be used to "rotate" the explosion

``LightningExplosion:Destroy()``\
Cleans up and clears from memory
