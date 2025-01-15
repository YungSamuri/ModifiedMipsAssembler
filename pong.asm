.data
screenStart: 16384    # 0x4000
screenEnd: 24576      # 0x6000
ballColor: 65535     # 0xFFFF (white in RGB565)
rowShift: 128
delay: 2500
myDelay: 10000
xVelocity: 1
yVelocity: 1
xEdge: 126
yEdge: 62

# Should start on row 31, column 64-65
# 31 * 128 + 63
startPix: 20415
ballPix: 20415

# right paddle started at 110 (128 - 18)
rightPaddleStart: 19566
rightPaddlePix: 19566

# Left paddle starts at
leftPaddleStart: 19474
leftPaddlePix: 19474

keyboardMem: 24576
upArrow: 38
downArrow: 40
wKey: 87
sKey: 83
spaceKey: 32

leftScore: 0
rightScore: 1

.text
j main

# Delays for 10000 ticks
debugLoop:
    lw R1, myDelay
    myDebugLoop:
        addi R1, R1, -1

        bne R1, R0, myDebugLoop

    jr R7


# This will clear the screen, reset the positions of the paddles/ball and wait for the user to press start
resetGame:
    # Increment SP
    addi R6, R6, -1
    sw R7, 0(R6)

    # Call the clear Screen function
    jal clearScreen

    # Reset ball/paddle position
    lw R1, startPix
    sw R1, ballPix

    lw R1, rightPaddleStart
    sw R1, rightPaddlePix

    lw R1, leftPaddleStart
    sw R1, leftPaddlePix

    # Then, draw everything to the screen
    lw R1, ballColor
    jal drawBall
    jal drawPaddle
    display

    # Finally, run a delay loop waiting for the user
    lw R1, spaceKey
    userResetLoop:
        lw R2, keyboardMem
        lw R2, 0(R2)
        bne R1, R2, userResetLoop

    # Load the return address and return
    lw R7, 0(R6)
    addi R6, R6, 1
    jr R7


clearScreen:
    lw R1, screenStart
    lw R2, screenEnd
    clearLoop:
        beq R1, R2, clearLoopEnd
        sw R0, 0(R1)         # Write black (0) to current pixel
        addi R1, R1, 1
        j clearLoop

    clearLoopEnd:

        jr R7

# R1 (arg)= pixel
# R1 (return value) = column
# R2 (return value) = row of that pixel
getRowCol:

    # Subtract the start pixel
    lw R2, screenStart
    sub R1, R1, R2

    # Run a loop to get the row/column
    addi R2, R0, 0  # Row
    lw R3, rowShift
    modulus_loop:
        # Check to see if R1 < 128. If so, then
        slt R4, R1, R3
        bne R4, R0, modulus_loop_end

        addi R2, R2, 1  # increment row counter
        sub R1, R1, R3  # subtract 128 from r1

        j modulus_loop

    modulus_loop_end:

    jr R7


# Returns if the ball is touching any walls and reverses velocity if needed
checkBounce:
    # First, store the return address on the stack
    addi R6, R6, -1
    sw R7, 0(R6)


    # Get the row/column of the ball
    lw R1, ballPix
    jal getRowCol

    # Check collisions

    # Left Wall
    beq R1, R0, hitLeft

    # Right Wall
    lw R3, xEdge
    beq R1, R3, hitRight

    # Top Wall
    beq R2, R0, hitTop

    # Bottom Wall
    lw R3, yEdge
    beq R2, R3, hitBottom

    # Right Paddle (2 pixels to the right of the ball)
    lw R1, ballPix
    lw R2, 2(R1)
    lw R3, ballColor
    beq R3, R2, hitRightPaddle

    # Check to see if 1 pixels to the left of the ball is white
    lw R1, ballPix
    lw R2, -1(R1)
    lw R3, ballColor
    beq R3, R2, hitLeftPaddle

    j bounce_done

    # If we hit the left wall, add 1 to left score and reset the ball
    hitLeft:
        lw R1, leftScore
        addi R1, R1, 1
        sw R1, leftScore
        jal resetGame
        j bounce_done

    hitRight:
        lw R1, rightScore
        addi R1, R1, 1
        sw R1, rightScore
        jal resetGame
        j bounce_done

    hitTop:
        addi R1, R0, 1
        sw R1, yVelocity
        j bounce_done

    hitBottom:
        addi R1, R0, -1
        sw R1, yVelocity
        j bounce_done

    hitRightPaddle:
        addi R1, R0, -1
        sw R1, xVelocity
        j bounce_done

    hitLeftPaddle:
        addi R1, R0, 1
        sw R1, xVelocity
        j bounce_done

    bounce_done:
        lw R7, 0(R6)
        addi R6, R6, 1
        jr R7

# Moves the ball in it's direction
moveBall:
    # First, add the x velocity to the ball's position
    lw R1, xVelocity
    lw R2, ballPix
    add R2, R2, R1  #pix = pix + velocity

    # Then, check whether the y velocity is -1 or 1
    addi R1, R0, 1
    lw R3, yVelocity
    lw R4, rowShift
    # if yvelocity == 1, then add the row shift, otherwise subtract
    bne R3, R1, moveUp
    # By default if R3 == R1, we move down
    moveDown:
        add R2, R2, R4
        j moveDone

    moveUp:
        sub R2, R2, R4

    moveDone:

    # Store the new ball pixel in memory
    sw R2, ballPix

    jr R7

# Checks for a keyboard input and moves the paddle if so
movePaddles:
    lw R1, keyboardMem
    lw R1, 0(R1)

    lw R2, upArrow
    beq R1, R2, rightUp

    lw R2, downArrow
    beq R1, R2, rightDown

    lw R2, wKey
    beq R1, R2, leftUp

    lw R2, sKey
    beq R1, R2, leftDown


    j leaveMovePaddle

    rightUp:
        lw R1, rightPaddlePix
        lw R2, rowShift
        sub R1, R1, R2
        sw R1, rightPaddlePix
        j leaveMovePaddle

    rightDown:
        lw R1, rightPaddlePix
        lw R2, rowShift
        add R1, R1, R2
        sw R1, rightPaddlePix
        j leaveMovePaddle

    leftUp:
        lw R1, leftPaddlePix
        lw R2, rowShift
        sub R1, R1, R2
        sw R1, leftPaddlePix
        j leaveMovePaddle

    leftDown:
        lw R1, leftPaddlePix
        lw R2, rowShift
        add R1, R1, R2
        sw R1, leftPaddlePix
        j leaveMovePaddle


    leaveMovePaddle:

    jr R7







# R1 = ball color
drawBall:
    # Load the current position of the ball into R2
    lw R2, ballPix

    # Draw the top 2 pixels
    sw R1, 0(R2)
    sw R1, 1(R2)

    # Shift the address down by a row
    lw R3, rowShift
    add R2, R2, R3

    # Draw the bottom 2 pixels
    sw R1, 0(R2)
    sw R1, 1(R2)

    jr R7

# R1 = color
drawPaddle:
    # First, draw the right paddle
    lw R2, rightPaddlePix
    lw R5, leftPaddlePix

    # Then, draw 5 offsets across and increas
    addi R3, R0, 14
    paddleLoop:
        sw R1, 0(R2)
        sw R1, 0(R5)
        sw R1, 1(R2)
        sw R1, 1(R5)
        sw R1, 2(R2)
        sw R1, 2(R5)


        # Then, shift R2 down by 128
        lw R4, rowShift
        add R2, R2, R4
        add R5, R5, R4

        addi R3, R3, -1

        bne R3, R0, paddleLoop

    jr R7



# Delays by the specified delay time
delay:
    addi R1, R0, 0
    lw R2, delay
    delayLoop:
        beq R1, R2, delayLoopEnd
        addi R1, R1, 1
        j delayLoop


    delayLoopEnd:
    jr R7

main:
    # Clear the screen
    jal resetGame

    drawLoop:

        # Check for a bounce
        jal checkBounce



        # First, clear the ball
        addi R1, R0, 0
        jal drawBall

        # Clear paddles
        addi R1, R0, 0
        jal drawPaddle

        # Then, move the ball
        jal moveBall

        # Move paddle
        jal movePaddles

        # Then, draw the ball again
        lw R1, ballColor
        jal drawBall


        # Draw the paddle
        lw R1, ballColor
        jal drawPaddle

        # Draw the current score as a series of boxes



        # Display
        display

        j drawLoop


   exit:
        j exit


    # Clear screen