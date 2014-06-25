extensions [ profiler ]    ;; uncomment this line for debuging

globals 
[ 
  hide-student-marks?                 ;; if true, student marks are not visible on teacher's view
  old-display-student-marks?          ;; used to detect the flipping of display-student-marks? switch 
  old-instruction-to-students         ;; used to detect any changes in the instruction text
  old-max-points                      ;; used to detect any changes in the max-points slider
  old-freeze?                         ;; used to detect the flipping of freeze? switch
  activity-start-filename             ;; holds the string containing activity start time, to be used as part of the filename, for both DATA and VIEW
  ;;got-new-data-update?              ;; for SAVE-REMINDER - not currently implemented
  ;;data-update-saved?                ;; for SAVE-REMINDER - not currently implemented
  selection                           ;; list to hold marks which are in selection
  selection-cumulative                ;; list to hold marks which came from multiple selection
]

breed [ students student ]
breed [ marks mark ]
breed [ sides side ]                  ;; for creating rectangular selector

students-own 
[ 
  user-id                            ;; unique id, input by student when they log in, to identify each point turtle
  points                             ;; a list to hold index number of the marks hatched by the student
  assigned-color                     ;; color which was initially assigned to the student
  active-color                       ;; currently active color used to paint the points
]

marks-own 
[ 
  my-user                           ;; string to hold user-id of the student who hatched this mark
  my-point                          ;; list to hold the coordinates of this point
  my-point-index                    ;; integer to hold index-number of this mark, as found in this mark's student's points list
  my-tag                            ;; string to hold tagginig label
  selected-color                    ;; color to be displayed when mark is in selection
  normal-color                      ;; color to be displayed when mark is not in selection
  selected-size                     ;; size to be displayed when mark is in selection
  normal-size                       ;; size to be displayed when mark is not ini selection
]


;;;;;;;;;;;;;;;;;;;;;;
;; SETUP PROCEDURES ;;
;;;;;;;;;;;;;;;;;;;;;;

to startup
  setup
end



to setup
  profiler:start                                    ;; uncomment this line to debug
  setup-vars
  hubnet-set-client-interface "COMPUTER" []
  hubnet-reset
end



to setup-vars
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  set-default-shape marks "dot"
  set-default-shape sides "line"
  set hide-student-marks? true
  set display-student-marks? false
  set old-display-student-marks? false
  clear-instruction
  set old-max-points max-points
  set freeze? false
  set old-freeze? false
  set selection no-turtles
  set selection-cumulative no-turtles
  set add-selection? false
  set tag-label ""
  set activity-start-filename get-unique-filename
  start-saving-data
end



to start-saving-data
  file-close-all
  show word "SAVED: " (word activity-start-filename "-DATA.csv")
  let fdata word activity-start-filename "-DATA.csv"
  file-open fdata
  show word "OPENED: " fdata
  ;;set got-new-data-update? false                     ;; for SAVE-REMINDER, not currently implemented
  ;;set data-update-saved? false                       ;; for SAVE-REMINDER, not currently implemented
  print-file-header
  file-flush
end

to print-file-header          
  file-print "DATA FILE - Visual Assessment Activity"     
  file-print ( word "Teacher:" "[Teacher_Name]" )
  file-print "[BEGIN DATA]"
  file-print "Name,Timestamp,Event,Point No,X Coord, Y Coord, Tag"
  
end



to-report get-unique-filename
  let startfn ( word ( replace-item 15 ( replace-item 12 ( replace-item 5 ( replace-item 2 date-and-time "-" ) "-" ) "_" ) "_" ) "--VA" )
  report startfn
end


to go
  every 0.1
  [
      if (freeze? != old-freeze?) 
      [
        ifelse (freeze?)
        [ 
          ask-concurrent students
          [ hubnet-send user-id "instruction" "ACTIVITY PAUSED!" ]
          file-print (word "Teacher, " date-and-time ",PAUSE") 
        ]
        [ 
          ask-concurrent students
          [ hubnet-send user-id "instruction" instruction-to-students ]
          file-print (word "Teacher, " date-and-time ",RESUME") 
        ]
        file-flush
        set old-freeze? freeze?         
      ]
    listen-clients
    
    if mouse-down? [
      deselect
    
      let old-x mouse-xcor
      let old-y mouse-ycor
    
      while [ mouse-down? ] [
        let new-x mouse-xcor
        let new-y mouse-ycor
        select old-x old-y new-x new-y
        display
      ] ;; end while mouse-down
      update-selection-cumulative
    ] ;; end if mouse-down
    display
  ] ;; end every 0.1
end

to listen-clients   
  while[  hubnet-message-waiting?  ]
  [
   hubnet-fetch-message
   
   ifelse ( hubnet-enter-message? )
   [  
     student-in  
   ]
   [
     ifelse ( hubnet-exit-message? )
     [
       student-out 
     ]
     [
       ifelse ( member? "View" hubnet-message-tag )
       [
         ifelse (freeze?) 
         []
         [ 
           ;;check-new-data-update
           add-point 
         ]
       ]
       [
         ifelse ( hubnet-message-tag = "color" )
         [ 
           print( hubnet-message )
           ask-concurrent students with [ user-id = hubnet-message-source ]
             [ 
               let color-num 0
               ifelse( hubnet-message = "assigned" ) [ set color-num assigned-color ] [
                 ifelse( hubnet-message = "red" ) [ set color-num 15 ] [
                   ifelse( hubnet-message = "green" ) [ set color-num 55 ] [
                     ifelse( hubnet-message = "blue" ) [ set color-num 105 ] [ set color-num 0 ] ] ] ]
               set active-color color-num
               print( hubnet-message )  
             ]
         ]
         [
           ifelse ( hubnet-message-tag = "undo-last" )
           [
             ifelse (freeze?)
             []
             [ 
               ;;check-new-data-update
               remove-last-point 
             ]
           ]
           [
             ifelse (hubnet-message-tag = "clear-all" )
             [
               ifelse (freeze?)
               []
               [ 
                 ;;check-new-data-update
                 remove-all-points 
               ]
             ]
             []
           ]
         ]
       ]
     ];else on exit-message
   ];else on enter-message
  ] ; end while hubnet-message-waiting?
  
  
  if (old-instruction-to-students != instruction-to-students)
  [
    file-print (word "Teacher," date-and-time "," "INSTRUCTION: " instruction-to-students) 
    file-flush
    ask-concurrent students
    [
      hubnet-send user-id "instruction" instruction-to-students
    ] ; end ask-concurrent students
    set old-instruction-to-students instruction-to-students
  ] ; end if (old-inst != inst)
  
  if (old-max-points != max-points )
  [
    ask-concurrent students
    [ hubnet-send user-id "max-allowed" max-points ]
  ] ;; end if (old-max-pts != max-pts)
  
  
  if (old-display-student-marks? != display-student-marks?) 
  [
    if (display-student-marks? = true )   
    [
      show-student-marks
      set hide-student-marks? false
    ]
    if (display-student-marks? = false )
    [
      hide-student-marks
      set hide-student-marks? true
    ]
    set old-display-student-marks? display-student-marks?
  ]
end



to add-point
  ask-concurrent students with [ user-id = hubnet-message-source ]
  [
    if ( length points < max-points )
    [
      set points lput hubnet-message points
      setxy item 0 hubnet-message item 1 hubnet-message
      set hidden? false
      set color active-color                                                                     
      hatch-marks 1 
      [ 
        set my-user ([user-id] of myself)  
        set my-point hubnet-message 
        set my-point-index ( position my-point [ points ] of myself ) + 1
        
        ask-concurrent students with [ user-id = hubnet-message-source ]
        [
          hubnet-send-override user-id myself "hidden?" [false]
          update-counts
        ]
        file-print ( word my-user "," date-and-time "," "ADD" "," length [ points ] of myself "," ( [xcor] of self) "," ( [ycor] of self) );; write to data file name, timestamp, event, point number, pointX, pointY
        file-flush
        ask-concurrent students with [ user-id != hubnet-message-source ]
        [
          hubnet-send-override user-id myself "hidden?" [true]
        ]
        set hidden? hide-student-marks?
        set normal-color ( [ active-color ] of myself )
        set selected-color ( [ active-color ] of myself )
        set normal-size size
        set selected-size size + 2
      ]
      set hidden? true
    ]
  ]
end



to remove-last-point
  let point []
  ask-concurrent students with [ user-id = hubnet-message-source ]
  [ 
    if ( length points > 0 )
    [
      ask-concurrent marks with [ my-user = [ user-id ] of myself and my-point = last [ points ] of myself ]    ;; get the last mark
      [
        file-print ( word my-user "," date-and-time "," "DELETE" "," length [ points ] of myself "," ( [xcor] of self) "," ( [ycor] of self) );; write to data file name, timestamp, event, point number, pointX, pointY
        file-flush
      ]
      
      set point last points 
      set points butlast points
      update-counts
    ]
  ]
  if any? marks with [ my-user = hubnet-message-source   and   my-point = point ]
  [ ask one-of marks with [ my-user = hubnet-message-source   and   my-point = point ] [die]  ]
   
end

to hide-student-marks
  ask-concurrent marks [ set hidden? true ]
  set hide-student-marks? true
end



to show-student-marks
  ask-concurrent marks [ set hidden? false ]
  set hide-student-marks? false
end

to clear-student-work
  save-current-view                               ;; saves current view when button's pressed
  file-print ( "[END DATA]" )
  file-close-all
  ;; set data-update-saved? true                ;; for SAVE-REMINDER, not currently impelemented
  ask-concurrent marks [ die ]
  ask-concurrent students [ set points []  update-counts ]
  set activity-start-filename get-unique-filename
  start-saving-data
end

to remove-all-points
  ask-concurrent students with [ user-id = hubnet-message-source ]
  [
    ask-concurrent marks with [ my-user = hubnet-message-source ]    ;; get all of the marks
    [
      let pos ( position my-point [ points ] of myself ) + 1
      file-print ( word my-user "," date-and-time "," "DELETE" "," pos "," ( [xcor] of self) "," ( [ycor] of self) );; write to data file name, timestamp, event, point number, pointX, pointY
      file-flush
    ]
  ]
  ask-concurrent marks with [ my-user = hubnet-message-source ] [ die ]
  ask-concurrent students with [ user-id = hubnet-message-source ] 
  [ 
    set points []  
    update-counts
  ]
end



to student-in
  ask-concurrent marks with [ my-user != hubnet-message-source ]
  [
    hubnet-send-override hubnet-message-source self "hidden?" [ true ]
  ]
  create-students 1
  [
    set user-id hubnet-message-source
    set points []
    set size 2
    setxy 0 0
    set shape "dot"
    set hidden? true
    set assigned-color ( ( ( random 14 ) * 10 ) + 5 )
    set color assigned-color
    set active-color color
    update-counts
    hubnet-send user-id "instruction" instruction-to-students
  ]
end



to update-counts 
  hubnet-send user-id "number-of-points" length points
  hubnet-send user-id "max-allowed" max-points
end



to student-out
  ask-concurrent students with [ user-id = hubnet-message-source ] [ die ]
  ask-concurrent marks with [ my-user = hubnet-message-source ] [ die ]
end

to save-current-view
  let fview word activity-start-filename "-VIEW.png"
  let fworld word activity-start-filename "-WORLD.csv"
  deselect
  let current-hide-student-marks? hide-student-marks?
  set hide-student-marks? false
  show-student-marks
  export-view fview
  export-world fworld
  show word "SAVED: " fview
  show word "SAVED: " fworld
  set hide-student-marks? current-hide-student-marks?
  if (hide-student-marks?)
  [
    hide-student-marks 
  ]
end

;;to check-new-data-update                                                 ;; for SAVE-REMINDER - not currently implemented
;;  if ( got-new-data-update? = false and data-update-saved? = false )
;;  [ set got-new-data-update? true ]
;;end

to clear-instruction
  set instruction-to-students ""
  set old-instruction-to-students ""
end

to make-side[ p1 q1 p2 q2 ]
  create-sides 1[
    set color white
   setxy ( p1 + p2 ) / 2
         ( q1 + q2 ) / 2 
    facexy p1 q1
    set size 2 * distancexy p1 q1

  ]
end

to-report selected? [ xsel ysel ]
  if not any? sides [ report false ]
  let y-max max[ ycor ] of sides
  let y-min min[ ycor ] of sides
  let x-max max[ xcor ] of sides
  let x-min min[ xcor ] of sides
  report xsel >= x-min and xsel <= x-max and
         ysel >= y-min and ysel <= y-max
end

to deselect
  ask-concurrent sides[ die ]
  ask-concurrent selection [ 
    off-effects
  ]
  set selection no-turtles
end

to select[ old-x old-y new-x new-y ]
  deselect
  make-side old-x old-y old-x new-y
  make-side old-x new-y new-x new-y
  make-side new-x old-y new-x new-y
  make-side old-x old-y new-x old-y
  set selection marks with [ selected? xcor ycor ]
  
  
  ask-concurrent selection[                          ;; so current marks' effects follows the active selection rectangle
    on-effects 
  ]
  
  ifelse add-selection? 
  [
    ask-concurrent selection-cumulative [             ;; so previously selected marks stay on effects
      on-effects
    ]
  ]
  [
    ask-concurrent selection-cumulative [              ;; so previously selected marks return to normal appearance
      off-effects
    ] 
  ]
  
end

to tag-selected-marks
  ask-concurrent selection-cumulative[ 
    set my-tag tag-label 
    file-print ( word my-user "," date-and-time "," "TAGGED" "," my-point-index "," xcor "," ycor "," my-tag ) ;; writes the tag label and point details to file
    file-flush
    deselect        ;; to deselect as soon as the Tag button was pressed
    ask-concurrent selection-cumulative [ off-effects ]
    set selection-cumulative no-turtles
  ]
end

to tag-untagged-marks               ;; NOT CURRENTLY USED
  ask-concurrent marks with [ my-tag = 0 ] [ 
    set my-tag tag-label 
    file-print ( word my-user "," date-and-time "," "TAGGED" "," my-point-index "," xcor "," ycor "," my-tag ) ;; writes the tag label and point details to file
    file-flush
    deselect
  ]
end

to update-selection-cumulative
  if not any? selection [                    ;; if no marks are in the selection rectangle, normalize effects and empty selection-cumulative
    ask-concurrent selection-cumulative [
      off-effects
    ]
    set selection-cumulative no-turtles 
  ]
  ifelse add-selection?
  [
    ifelse any? selection-cumulative [
      set selection-cumulative ( turtle-set selection-cumulative selection )    ;; add new marks into selection-cumulative
    ]
    [
      set selection-cumulative selection                                        ;; initialize selection-cumulative
    ]
  ]
  [
    set selection-cumulative selection                                          ;; refresh selection-cumulative using selection
  ]
  ask-concurrent selection-cumulative[                  ;; enable effects
    set size selected-size
    set color selected-color 
  ]
end

to inverse-selection
  ask-concurrent selection-cumulative[               ;; normalize effects
   off-effects
  ]
  let temp-selection-cumulative selection-cumulative                   ;; prepare to swap
  set selection-cumulative marks with [ not member? self temp-selection-cumulative ]
  ask-concurrent selection-cumulative[               ;; activate effects
    on-effects
  ]
end

to on-effects
  set size selected-size
  set color selected-color
end

to off-effects
  set size normal-size
  set color normal-color
end
@#$#@#$#@
GRAPHICS-WINDOW
214
16
653
476
16
16
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
17
16
202
49
Set Image (Save)
clear-student-work\nclear-instruction\nclear-drawing\nimport-drawing user-file\nfile-print (word \"Teacher,\" date-and-time \",LOAD IMAGE: user-file\" )\nfile-flush\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
17
210
202
299
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
665
99
868
132
max-points
max-points
1
10
4
1
1
points allowed
HORIZONTAL

TEXTBOX
29
60
223
78
 (BMP, JPG, GIF, or PNG supported)
8
0.0
1

BUTTON
17
76
202
109
Save and Clear
clear-student-work\nclear-instruction\nask students \n[\n  hubnet-send user-id \"instruction\" \"\"\n  hubnet-send user-id \"max-allowed\" max-points\n]\nstart-saving-data\n\n;; uncomment the following lines to debug\n;;profiler:stop\n;;file-open \"VA v0.9 ProfilerDump-Scen-Rep-.txt\"\n;;file-print profiler:report\n;;file-close
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
665
16
868
92
instruction-to-students
NIL
1
0
String

SWITCH
17
121
202
154
display-student-marks?
display-student-marks?
1
1
-1000

SWITCH
17
165
202
198
freeze?
freeze?
1
1
-1000

MONITOR
65
310
202
363
Students Logged-in
count students
0
1
13

INPUTBOX
666
286
869
346
tag-label
NIL
1
0
String

BUTTON
666
355
870
390
Tag Selected Marks
tag-selected-marks
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
670
225
869
290
To tag marks:\n     1. Select the marks\n     2. Type in the Label\n     3. Click \"Tag Selected Marks\"
10
0.0
1

SWITCH
666
398
870
431
add-selection?
add-selection?
1
1
-1000

BUTTON
666
441
870
474
Inverse Selection
inverse-selection
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0RC3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
4
10
433
439
0
0
0
1
1
1
1
1
0
1
1
1
-16
16
-16
16

BUTTON
167
520
288
566
undo-last
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
297
520
436
567
clear-all
NIL
NIL
1
T
OBSERVER
NIL
NIL

MONITOR
104
598
224
647
number-of-points
NIL
1
1

TEXTBOX
111
445
331
463
click in the drawing area to mark a point
11
0.0
1

MONITOR
237
598
363
647
max-allowed
NIL
3
1

MONITOR
7
461
435
510
instruction
NIL
0
1

CHOOSER
8
520
158
565
color
color
"assigned" "red" "green" "blue"
0

@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
