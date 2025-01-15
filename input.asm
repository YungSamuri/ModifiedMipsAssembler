.data
    screenStart: 16384
    screenEnd: 24576
    keyboardMem: 24576
    spaceKey: 32

.text
    j main

updateScreen:
    lw R1, screenStart
    lw R2, screenEnd
    lw R4, spaceKey
    lw R5, keyboardMem
    lw R5, 0(R5)

    bne R5, R4, endLoop

    addi R3, R3, 30
    addi R3, R3, 30
    addi R3, R3, 30

    displayLoop:
        beq R1, R2, endLoop

        sw R3, 0(R1)
        addi R1, R1, 1

        display

        j displayLoop

    endLoop:
        jr R7


main:
    lw R1, screenStart
    lw R2, screenEnd
    add R3, R0, R0

    initializeLoop:
        beq R1, R2, drawLoop

        sw R3, 0(R1)
        addi R1, R1, 1

        display

        j initializeLoop

    drawLoop:

        jal updateScreen

        j drawLoop