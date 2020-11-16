unit amEasing;

(*
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is amEasing

  The Initial Developer of the Original Code is Anders Melander.

  Portions created by the Initial Developer are Copyright (C) 2002
  the Initial Developer. All Rights Reserved.

  Contributor(s):
    -

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.
*)

interface

// -----------------------------------------------------------------------------
//
//      Easing / Tweening animation
//
// -----------------------------------------------------------------------------
// See:
// - Robert Penner's Easing Functions
//   http://robertpenner.com/easing/
//
// - Motion, Tweening, and Easing
//   http://robertpenner.com/easing/penner_chapter7_tweening.pdf
//
// - Easing Functions Cheat Sheet
//   http://easings.net
// -----------------------------------------------------------------------------

type
  // Ease function prototype.
  // Value: [0..1]
  // Result: [0..1]
  TEaseFunc = function(Value: Double): Double;

  // Ease/Tween performer prototype.
  // Value: [0..1]
  TEasePerformer = reference to procedure(Value: Double; var Continue: boolean);


// Tween/Easing engine
procedure AnimatedTween(EaseFunc: TEaseFunc; Duration: integer; Performer: TEasePerformer; Throttle: integer = 0; InitialThrottle: boolean = False);

(*
        Example of usage:

        Move the position of a button using the Bounce/Elastic animation.

            AnimatedTween(EaseOutElastic, 2000,
              procedure(Value: Double; var Continue: boolean)
              begin
                // Move from Left=20 to Left=100
                Button1.Left := 20 + Trunc(Value * 80);
              end, 40);

        The animation will take 2 seconds.
        Each frame/step will take a minimum of 40 mS.
        The animation will perform up to 50 frames or steps (50 = 2000/40) with
        a maximum frame rate of 25 fps (25 = 1000/40)
*)

// -----------------------------------------------------------------------------
//
//      Easing functions
//
// -----------------------------------------------------------------------------
function EaseLinear(Value: Double): Double;
function EaseInOutCubic(Value: Double): Double;
function EaseInOutQuartic(Value: Double): Double;
function EaseOutBack(Value: Double): Double;
function EaseOutBack2(Value: Double): Double;
function EaseOutElastic(Value: Double): Double;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

implementation

uses
  Math,
  Windows,
  System.Diagnostics;

// -----------------------------------------------------------------------------

function EaseLinear(Value: Double): Double;
begin
  Result := Value;
end;

// Modeled after the piecewise cubic
// y = (1/2)((2x)^3)       ; [0, 0.5)
// y = (1/2)((2x-2)^3 + 2) ; [0.5, 1]
function EaseInOutCubic(Value: Double): Double;
begin
  Value := Value * 2;

  if (Value < 1) then
    Result := 0.5 * Value * Value * Value
  else
  begin
    Value := Value - 2;

    Result := 0.5 * (Value * Value * Value + 2);
  end;
end;

// Modeled after the piecewise quartic
// y = (1/2)((2x)^4)        ; [0, 0.5)
// y = -(1/2)((2x-2)^4 - 2) ; [0.5, 1]
function EaseInOutQuartic(Value: Double): Double;
begin
  Value := Value * 2;

  if (Value < 1) then
    Result := 0.5 * Value * Value * Value * Value
  else
  begin
    Value := Value - 2;

    Result := -0.5 * (Value * Value * Value * Value - 2);
  end;
end;

// Modeled after the overshooting cubic
// y = (1-x)^2*((x+1)*(1-x)+x)+1
function EaseOutBack(Value: Double): Double;
const
  s = 1.70158;
begin
  Value := Value - 1;
  Result := Value * Value * ((s + 1) * Value + s) + 1;
end;

// Modeled after the overshooting cubic
// y = 1-((1-x)^3-(1-x)*sin((1-x)*pi))
// Overshoots a bit more than EaseOutBack
function EaseOutBack2(Value: Double): Double;
begin
  Value := 1 - Value;
  Result := 1 - (Value * Value * Value - Value * Sin(Value * Pi));
end;

// Modeled after the damped sine wave
// y = sin(-13pi/2*(x + 1))*pow(2, -10x) + 1
function EaseOutElastic(Value: Double): Double;
begin
  if (Value = 0) then
    Exit(0);

  if (Value = 1) then
    Exit(1);

  Result := Sin(-13 / 2 * Pi * (Value + 1)) * Math.Power(2, -10 * Value) + 1;
end;

// -----------------------------------------------------------------------------

procedure AnimatedTween(EaseFunc: TEaseFunc; Duration: integer; Performer: TEasePerformer; Throttle: integer; InitialThrottle: boolean = False);
var
  Stopwatch: TStopwatch;
  Elapsed: int64;
  Value: Double;
  RemainingThrottle: int64;
  Continue: boolean
begin
  (*
  ** Performs time controlled tweening using an easing function.
  *)

  Stopwatch := TStopwatch.StartNew;
  Elapsed := 0;
  Continue := True;

  while (Continue) and (Elapsed <= Duration) do
  begin
    // Throttle
    if ((Elapsed <> 0) or (InitialThrottle)) and (Throttle <> 0) and (Elapsed < Duration) then
    begin
      // Make sure we don't wait too long
      RemainingThrottle := Duration - Stopwatch.ElapsedMilliseconds;
      if (RemainingThrottle > 0) then
        Sleep(Min(RemainingThrottle, Throttle));

      // Calculate time elapsed during throttle
      Elapsed := Stopwatch.ElapsedMilliseconds;
    end;

    if (Elapsed > Duration) then
      Elapsed := Duration;

    // Calculate tween value...
    Value := EaseFunc(Elapsed / Duration);
    // ...and Ease
    Performer(Value, Continue);

    // Calculate time elapsed during Ease
    Elapsed := Stopwatch.ElapsedMilliseconds;
  end;
end;

// -----------------------------------------------------------------------------

end.
