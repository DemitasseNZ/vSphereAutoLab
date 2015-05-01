Dim goal, before, x, y, i
goal = 5000000
Do While True
	before = Timer
	For i = 0 to goal
		x = 0.000001
		y = sin(x)
		y = y + 0.00001
	Next
	y = y + 0.01
	WScript.Echo "I did five million sines in " &  Int(Timer - before + 0.5) & " seconds!"
Loop
