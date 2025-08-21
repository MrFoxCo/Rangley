//
//  README.md
//  Freebird
//
//  Created by Anthony Guzzardo on 7/6/25.
//
# ADDRESS THESE ISSUES OR YOUR APP WILL EXPLODE
##  HELPFUL INFORMATION FOR THROTTLING
- YOU CANNOT MAKE MORE THAN 50 requests in 60 seconds for GEOCODING
    - Must prevent people from tapping on the screen that many times
Throttled "PlaceRequest.REQUEST_TYPE_REVERSE_GEOCODING" request: Tried to make more than 50 requests in 60 seconds, will reset in 37 seconds - Error Domain=GEOErrorDomain Code=-3 "(null)" UserInfo={details=(
        {
        intervalType = short;
        maxRequests = 50;
        "throttler.keyPath" = "app:com.mrfoxco.app/0x20304/short(default/any)";
        timeUntilReset = 37;
        windowSize = 60;
    }
), requestKindString=PlaceRequest.REQUEST_TYPE_REVERSE_GEOCODING, timeUntilReset=37, requestKind=772}
# ADDRESS THE ABOVE ISSUES OR YOUR APP WILL EXPLODE


## Documentation
[CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager)

# Rangle
Freebird -> MeetMate -> Chibuya -> Rangle

- Version 1 Controlled Release
    - Minimial Ukiyo-E themes
        - Color Pallette:
        🌊 Blues
            Prussian Blue (bero-ai) – #0F4C81
            Indigo (aizome) – #264653
            Light Sky Blue – #8BBBD9
            Blue-Grey – #6B93AA
        🌿 Greens
            Soft Leaf Green (moegi) – #6A9A1F
            Blue-Green / Teal (aomidori) – #3A796F
            Olive Green – #8A8F3A
        🌸 Reds / Pinks
            Vermilion Red (shu-iro) – #E34234
            Soft Pink – #F6C4C4
            Crimson (beni) – #A63A3A
            ☀️ Yellows / Golds
            Golden Yellow (yamabuki) – #FFC30B
            Pale Straw Yellow – #F2E5B3
        🌑 Neutrals
            Sumi Ink Black – #1C1C1C
            Warm Beige (paper tone) – #E9DCC9
            Cool Grey – #A6A6A6
    - LLC is created
    - Manually create users
    - Users can create meets, join meets
    - All meets are public
    - Color Schema Black and White
- Version 2 MVP
    - Ukiyo-E theme
    - Swipe Effect
    - Ukiyo-E Theme for category's and meet icons
    - Lasso Effect 
    - Public and Private
    -
- Version 3
    - Meet Driven Animations (e.g., tennis meetup tennis ball animations over event)
    - New color schema: green or yellow
    - LL
    
### Features 
- These will be manually inserted
public enum Features: Int, CaseIterable {
    case NULL_VALUE = 0
    case Event_Creation
    case Location_Sharing
//    case Chat
//    case Photos
//    case Private_Enabled
//    case Animations_Enabled
//    case App_Coloration_Enabled
}

VERSION 1
Controlled release

VERSION 2
Color pallete

VERSION 3
Itenarary Plan
Curated Suggestions


## AWS

ECS Fargate Cluseter pattern: rangley-<env>-<region> 
→ start with rangley-prod-use2 (and later rangley-stg-use2, rangley-dev-use2).
Keep it lowercase/hyphenated; add tags: project=rangley, env=prod, region=us-east-2, owner=anthony.


ECR = rangley-api
