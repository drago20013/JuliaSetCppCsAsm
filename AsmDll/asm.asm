.data
AlphaMask dd 3 dup (0ffffffffh), 0, 3 dup (0ffffffffh), 0
;an array of 32-bit doublewords (dd) that is initialized with 3 copies of the value 0xffffffff, followed by a single 0, followed by another 3 copies of the value 0xffffffff, and another 0. This creates an array of 8 doublewords with a pattern of 0xffffffff, 0xffffffff, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0.

NotAlphaMask dd 3 dup (0), 0ffffffffh, 3 dup (0), 0ffffffffh
;The "NotAlphaMask" is similar but consist of all zeroes except for 4 copies of 0xffffffff.

AAMask dd 4 dup(0ffffffffh, 0)
BBMask dd 4 dup(0, 0ffffffffh)

;"AAMask" and "BBMask" are each arrays of 4 doublewords, where each pair of doublewords is initialized with 0xffffffff and 0.

AbsMask dd 2 dup(0, 0, 07fffffffh, 07fffffffh)
;"AbsMask" is an array of 4 doublewords, each pair is initialised as 0 and 0x7fffffff which representing the absolute value of the 2's complement representation of a signed 32-bit integer.

WasSet dd 8 dup(-1)
;an array of 8 quadwords, each initialized with the value -1 (0xffffffffffffffff).


Ones real4 8 dup(1.0)
;"Ones" is an array of 4 single-precision floating-point values, each initialized with the value 1.0

Threashold real4 2 dup(0.0, 0.0, 16.0, 16.0)

;"Threshold" is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 16.0

Twos real4 4 dup(0.0, 2.0)
;"Twos" is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 2.0

ActualIterations dq 4 dup(0)
;"ActualIterations" is an array of 8 quadwords, each initialized with the value 0.

MaxBrightness real4 8 dup(255.0)
;"MaxBrightness" is an array of 4 single-precision floating-point values, each initialized with the value 255.0

;================================================================

.code
 ;CalculateMandelbrotASM
 ;ComplexCoord* inCoord,	RCX
 ;Pixel* outBMP,			RDX
 ;Settings settings,		R8 
							;c_r 
							;c_i +4
							;size +8
							;maxIter +12
JuliaAsm proc
	;1- load pixels
	mov r9d, dword ptr[r8+8] 
	;It starts by loading a 32-bit value from memory at the address in the R8 register plus 8 bytes into the R9 register. This value represents the size of an array of pixels.

	;2- initiate counter
	shr r9d, 2 
	;shifts the bits in the R9 register to the right by 2, which is equivalent to dividing the value stored in R9 by 4. This value is used as a main counter for processing the array of complex numbers.

	;3- storing maxIterations, internal loop counter
	mov r11d, dword ptr[r8+12] 
	;loads a 32-bit value from memory at the address in the R8 register plus 12 bytes into the R11 register. This value represents the maximum number of iterations that the procedure will perform on each complex number.

	;4- preparing the maxIterations counter
	;The next group of instructions are related to broadcasting, by that it loads 64-bit value from R11 into xmm10, then duplicating the 64-bit value from xmm10 into xmm10 and then 128-bit value from xmm10 into ymm10. Then this ymm10 is loaded into another register ymm7 for the purpose of MaxIterations.
	vmovd  xmm10, r11d
	vpbroadcastd ymm10, xmm10
	vmovapd ymm7, ymm10 ;ymm7 = maxIterations

	;5- initiating C
	mov r10, qword ptr[r8] 
	;loads a 64-bit value from memory at the address in the R8 register into the R10 register. This value represents the constant complex number 'C' that is used in the calculation for each complex number in the array.

	;6- Brodcasting C 
	vmovq  xmm10, r10
	;will move the 64-bit value from r10 register and store it in the least significant 64 bits of the xmm10 register. The most significant 64 bits of xmm10 will be left unchanged.

	vpbroadcastq ymm10, xmm10
	;broadcasts from lower qw from xmm10 to all qw of ymm10 
	; after broadcasting we have 4 copies of (c_real, c_imag) in ymm10
	
	;7- AbsMask
	vmovaps	ymm8, [AbsMask]; ymm8 = AbsMask, this is an array of 4 doublewords, each pair is initialised as 0 and 0x7fffffff which representing the absolute value of the 2's complement representation of a signed 32-bit integer.
	
	;8-threshold (limit that decides whether a point is bounded or not)
	vmovaps ymm9, [Threashold]; ymm9 = Threashold, his is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 16.0
	
	vmovaps	ymm11, [AAMask]; ymm11 = AAMask, this is an array of 4 doublewords, where each pair is initialized with 0xffffffff and 0

	vmovaps	ymm12, [BBMask]; ymm12 = BBMask, this is an array of 4 doublewords, where each pair is initialized with 0 and 0xffffffff

	vmovaps	ymm13, [Twos]; ymm13 = Twos, this is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 2.0 (used for doubling values, since we cant just shift for floats)

	vmovaps	ymm14, [AlphaMask]; ymm14 = AlphaMask, this is an array of 8 doublewords with a pattern of 0xffffffff, 0xffffffff, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0.

	vmovaps	ymm15, [NotAlphaMask]; ymm15 = NotAlphaMask, this is an array of 8 doublewords with a pattern of 0,0,0,0,0,0,0,0 except for 4 copies of 0xffffffff
	 

MainLoop:
	vmovups	ymm0, ymmword ptr[rcx] ; loading coordinates
	; it loads the 256-bit value into the YMM0 register as an unaligned packed single-precision floating-point value
	
	xor r10, r10 ; current iterations 

	;Preparing the data initial state 
	;this section of the code loads a 256-bit complex number into the YMM0 register and sets the initial values for "WasSet" array, "ActualIterations" array, and the current iteration counter.
	;It also sets all elements in the WasSet array to -1, and all elements in the ActualIterations array to 0.
	mov rax, -1 
	vmovq xmm2, rax
	vpbroadcastq ymm2, xmm2
	vmovaps [WasSet], ymm2
	mov rax, 0
	vmovq xmm2,  rax
	vpbroadcastq ymm2, xmm2
	vmovapd [ActualIterations], ymm2

IterLoop:

	;1- get newReal
	vmulps ymm3, ymm0, ymm0 ;a*a, b*b, .........

	;performs a bitwise AND operation on the elements
	vandps ymm2, ymm3, ymm11 ; get a*a : a*a, 0, a*a, 0 .... 
	vandps ymm4, ymm3, ymm12 ; get b*b : 0, b*b, 0, b*b , ..... 

	vpshufd ymm2, ymm2, 93h ;0, a*a, 0, a*a ... now we have the desired "order" to get new a 

	vsubps ymm2, ymm2, ymm4 ;get newReal = a*a - b*b
	
	;2- get newImag part:
	vandps ymm4, ymm0, ymm11; get a => { a 0 a 0 } 
	vandps ymm3, ymm0, ymm12 ; get b  => {0 b 0 b}

	vpshufd ymm4, ymm4, 93h ; shuffling to arrange the data in the desired way 

	vmulps ymm6, ymm3, ymm4 ;a*b
	vmulps ymm6, ymm6, ymm13 ; newImag = 2*a*b

	;3- merge newReal and newImag ymm2
	vpshufd ymm2, ymm2, 39h
	vorps ymm2, ymm2, ymm6; bitwise OR ==> combining the values of aa and bb*i together in YMM2.

	;4- get the new Z = (aa+bb*i) + (ca+cb*i)
	vaddps ymm0, ymm10, ymm2

	;5- check if threshold exceeded
	;if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
	;a - ymm4
	;b - ymm3
	vhaddps ymm3, ymm0, ymm0; inComplexCoord[i].x + inComplexCoord[i].y (horizontal addition)
	
	vandps ymm3, ymm3, ymm8; get the absolute values of (inComplexCoord[i].x + inComplexCoord[i].y) .

	;5a- if larger do not update number of iterations
	vcmpgtps ymm3, ymm3, ymm9

	vpshufd ymm3, ymm3, 00110110b ; shuffling to arrange in the desired way
	vmovd xmm2, r10d ; the current iteration number (n)

	vpbroadcastq ymm2, xmm2 ;takes the 64-bit value in the XMM2 register and broadcast it
	vmovapd ymm4, [ActualIterations] ; previous values after processing in last iteration

	;this part is a safe guard to not override values for pixels that are already unbounded and save their needed number of iterations that will be used for the colors
	vandps ymm2, ymm2, ymm3 ; ymm2 : either (0 -> dont update n) or (n -> might update the actual iterations counter)

	vandps ymm2, ymm2, [WasSet] ;filter pixles that were set in previous iterations
	vorpd ymm2, ymm2, ymm4 ;updating the iteraction counter for the current 4 pixels

	vmovapd [ActualIterations], ymm2 ; saving the actual iteration for each pixel where it finished processing to the memory so the reg can be reused

;the next section is checking each pixel of the current 4 is already determined to be unbounded
;then it updates its mask (which is temporarily saved in rsi)
; until all 4 pixels are set (which means they went over the threshold which means they are unbound. then we move to the next group of the next 4 pixels)
	pextrd eax, xmm3, 0 ; extract 1 dw from xmm whic represents the state of 1 pixel
	mov rsi, -1
	cmp eax, 0 ;; Set first one when greater than threashold
	je NotSet1 ;not yet bounded
	mov rsi, 0

;each jump of the next 3 jumps is the above mentioned check for each pixel in the 4 
NotSet1: ;checks 2nd pixel
	pinsrq xmm2, rsi, 0
	pextrd eax, xmm3, 2
	mov rsi, -1
	cmp eax, 0 ;; Set second one when greater than threashold
	je NotSet2
	mov rsi, 0

NotSet2: ;checks 3rd pixel
	pinsrq xmm2, rsi, 1
	vextracti128 xmm4, ymm3, 1

	pextrd eax, xmm4, 0
	mov rsi, -1
	cmp eax, 0 ;; Set third one when greater than threashold
	je NotSet3
	mov rsi, 0

NotSet3: ;checks 4th
	pinsrq xmm5, rsi, 0
	pextrd eax, xmm4, 2 
	mov rsi, -1
	cmp eax, 0 ;; Set fourth one when greater than threashold
	je NotSet4
	mov rsi, 0

NotSet4: ;either all 4 pixels are done processing and move to the next group of pixels or still at least one pixel is yet to be processed 

	pinsrq xmm5, rsi, 1
	vinserti128 ymm2, ymm2, xmm5, 1; merge xmm2 and xmm5 to ymm2, which creates was set mask
	vandps	ymm2, ymm2, [WasSet]
	vmovaps [WasSet], ymm2
	vhaddpd ymm2, ymm2, ymm2
	pextrq rax, xmm2, 0
	vextracti128 xmm2, ymm2, 1
	pextrq rsi, xmm2, 0
	add rax, rsi
	;check if all were set, if yes jump(actually just move further) out to _esc
	cmp rax, 0
	je IterLoop_esc

	inc r10d ;increase counter 
	cmp r10d, r11d ;check if we finished all loops
	jl IterLoop ; repeat if still more loops

IterLoop_esc:

	;=======================================================
	;Coloring

	vmovapd ymm2, [ActualIterations] ; n 0 n 0 n 0 n 0
	;;;;;;;;;;;;;vcvtdq2ps ymm2, ymm2
	;STEP 1: Remap actual iterations from 0-MaxTterations to 0-1 floating point
	;ymm2 = toLow + (ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)

	;(ymm2 - fromLow) = ymm2
	;vxorpd ymm0, ymm0, ymm0; ymm0 = 0 - > fromLow		;
	;vsubpd ymm2, ymm2, ymm0; ymm2 = values - fromLow	
	; In our case always value - 0 so skipping these steps

	;(toHigh - toLow) = ymm3
	;vmovapd ymm3, ymmword [Ones]; ymm3 = 1.0 -> toHigh	;
	;vsubpd ymm3, ymm3, ymm0							
	; again 1 - 0 is 1 always

	;(ymm2 - fromLow) * (toHigh - toLow) = ymm2
	;vmulpd	ymm2, ymm2, ymm3; and once again 5*1 is 5 so skipping

	;(fromHigh - fromLow), ymm7 -> maxIter -> fromHigh, fromLow=0 so useless
	;(ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
	vdivps ymm2, ymm2, ymm7

	;lastly add toLow to ymm2, but toLow is 0 so useless
	;now in ymm2 should be the values mapped from 0->maxIter to 0->1

	;STEP 2: Take sqrt of these values

	vsqrtps ymm2, ymm2

	;STEP 3: Remap values after sqrt from 0-1 to 0-255

	;load MaxBrightness(toHigh) to ymm3, and substract from it toLow, but its 0 so again result is MaxBrightness
	vmovaps ymm3, [MaxBrightness]
	
	;(ymm2(values-fromLow) * ymm3(toHigh - toLow) = ymm2
	vmulps	ymm2, ymm2, ymm3

	;(ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow), fromHigh is [Ones], fromLow is 0
	;so its ymm2 / [Ones] and anything divided by 1 is itself so skipping this step
	
	;lastly add toLow to ymm2, but toLow is 0 so useless
	;now in ymm2 should be the values mapped from 0->1 to 0->255
	;Values should be back in the ymm2

	;calculate each part of color and put it back to pixel
	;vmovups	ymm0, ymmword ptr[rdx]
	
	;saving color values to the output array
	vextractf128 xmm4, ymm2, 0
	;first pixel
	extractps eax, xmm4, 0
	vmovd xmm3, eax
	vbroadcastss xmm3, xmm3

	;second
	extractps eax, xmm4, 2
	vmovd xmm4, eax
	vbroadcastss xmm4, xmm4
	vinsertf128 ymm3, ymm3, xmm4, 1
	vmovupd ymmword ptr[rdx], ymm3 
	; save two pixels data and move pointer and load data for next two	
	add rdx, 32 ;skip to the next pixel
	vextractf128 xmm4, ymm2, 1

	;third
	extractps eax, xmm4, 0
	vmovd xmm3, eax
	vbroadcastss xmm3, xmm3

	;fourth
	extractps eax, xmm4, 2
	vmovd xmm4, eax
	vbroadcastss xmm4, xmm4
	vinsertf128 ymm3, ymm3, xmm4, 1
	vmovupd ymmword ptr[rdx], ymm3
	add rdx, 32 ; prepare address for the next time
	add rcx, 32 ;same
	dec r9d ;size of array left to be done
	jnz MainLoop

	ret
JuliaAsm endp
end