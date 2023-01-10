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

WasSet dq 4 dup(-1)
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
	mov r9d, dword ptr[r8+8] 
	;It starts by loading a 32-bit value from memory at the address in the R8 register plus 8 bytes into the R9 register. This value represents the size of an array of complex numbers.

	shr r9d, 2 
	;shifts the bits in the R9 register to the right by 2, which is equivalent to dividing the value stored in R9 by 4. This value is used as a main counter for processing the array of complex numbers.

	mov r11d, dword ptr[r8+12] ; storing maxIterations, internal loop counter
	;loads a 32-bit value from memory at the address in the R8 register plus 12 bytes into the R11 register. This value represents the maximum number of iterations that the procedure will perform on each complex number.

	;The next group of instructions are related to broadcasting, by that it loads 64-bit value from R11 into xmm10, then duplicating the 64-bit value from xmm10 into xmm10 and then 128-bit value from xmm10 into ymm10. Then this ymm10 is loaded into another register ymm7 for the purpose of MaxIterations.
	vmovq  xmm10, r11
	vpinsrq xmm10, xmm10, r11, 1
	vinserti128 ymm10, ymm10, xmm10, 1
	vmovapd ymm7, ymm10 ;ymm7 = maxIterations

	mov r10, qword ptr[r8] 
	;loads a 64-bit value from memory at the address in the R8 register into the R10 register. This value represents the constant complex number 'C' that is used in the calculation for each complex number in the array.
	vmovq  xmm10, r10
	;will move the 64-bit value from r10 register and store it in the least significant 64 bits of the xmm10 register. The most significant 64 bits of xmm10 will be left unchanged.
	vpinsrq xmm10, xmm10, r10, 1
	;performs an insert operation on the XMM10 register. It takes the lower 64-bits of the XMM10 register and the 64-bit value in R10, and inserts them into a 128-bit destination specified by the destination XMM10 register.
	;This sequence is a bit tricky but it's a way to copy a 64-bit value into a 128-bit XMM register, in this case, it's used to insert the 64-bit value of C into the XMM10 register in order to have 2 copies of C (c_real, c_imag) in this register.

	vinserti128 ymm10, ymm10, xmm10, 1 ; after broadcasting we have 4 copies of (c_real, c_imag) in ymm10
	
	vmovaps	ymm8, [AbsMask]; ymm8 = AbsMask, this is an array of 4 doublewords, each pair is initialised as 0 and 0x7fffffff which representing the absolute value of the 2's complement representation of a signed 32-bit integer.
	
	vmovaps ymm9, [Threashold]; ymm9 = Threashold, his is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 16.0
	
	vmovaps	ymm11, [AAMask]; ymm11 = AAMask, this is an array of 4 doublewords, where each pair is initialized with 0xffffffff and 0
	vmovaps	ymm12, [BBMask]; ymm12 = BBMask, this is an array of 4 doublewords, where each pair is initialized with 0 and 0xffffffff

	vmovaps	ymm13, [Twos]; ymm13 = Twos, this is an array of 4 single-precision floating-point values, each pair is initialized with 0.0 and 2.0

	vmovaps	ymm14, [AlphaMask]; ymm14 = AlphaMask, this is an array of 8 doublewords with a pattern of 0xffffffff, 0xffffffff, 0xffffffff, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0.

	vmovaps	ymm15, [NotAlphaMask]; ymm15 = NotAlphaMask, this is an array of 8 doublewords with a pattern of 0,0,0,0,0,0,0,0 except for 4 copies of 0xffffffff
	 

MainLoop:
	vmovups	ymm0, ymmword ptr[rcx] ; loading coordinates
	; it loads the 256-bit value into the YMM0 register as an unaligned packed single-precision floating-point value
	
	xor r10, r10 ; current iterations 

	mov rax, -1 
	vmovq xmm2, rax
	vpbroadcastq ymm2, xmm2
	vmovapd [WasSet], ymm2
	mov rax, 0
	vmovq xmm2,  rax
	vpbroadcastq ymm2, xmm2
	vmovapd [ActualIterations], ymm2
	;this section of the code loads a 256-bit complex number into the YMM0 register and sets the initial values for "WasSet" array, "ActualIterations" array, and the current iteration counter.
	;It also sets all elements in the WasSet array to -1, and all elements in the ActualIterations array to 0.

IterLoop:
	;mov r10d, r8d ; to calculate actual iterations

	vmulps ymm3, ymm0, ymm0 ;a*a, b*b, .........

;performs a bitwise AND operation on the elements
	vandps ymm2, ymm3, ymm11 ; get a*a : a*a, 0, a*a, a .... 
	vandps ymm4, ymm3, ymm12 ; get b*b : 0, b*b, 0, b*b , ..... 

	vpshufd ymm2, ymm2, 93h ;0, a*a, 0, a*a ... now we have the desired "order" to get new a 

	vsubps ymm2, ymm2, ymm4 ;get aa = a*a - b*b
	
	;now to get bb = 2*a*b
	vandps ymm3, ymm0, ymm12 ; get b by ANDing {a , b , ....} * {Bmask}
	vandps ymm4, ymm0, ymm11; get a

	vpshufd ymm4, ymm4, 93h

	vmulps ymm6, ymm3, ymm4 ;a*b
	vmulps ymm6, ymm6, ymm13 ; bb = 2*a*b

	;merge aa and bb to ymm2
	vpshufd ymm2, ymm2, 39h
	vorps ymm2, ymm2, ymm6

	;Z = (aa+bb*i) + (ca+cb*i)
	vaddps ymm0, ymm10, ymm2

	;if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
	;a - ymm4
	;b - ymm3
	vhaddps ymm3, ymm0, ymm0; inComplexCoord[i].x + inComplexCoord[i].y
	
	vandps ymm3, ymm3, ymm8; Abs


	;vmovaps ymm5, [Threashold]
	
	;if larger break and save number of iterations--------
	
	vcmpgtps ymm3, ymm3, ymm9

	vpshufd ymm3, ymm3, 00110110b

	vmovd xmm2, r10d
	vpbroadcastq ymm2, xmm2
	vmovapd ymm4, [ActualIterations] ; previous values
	vandps ymm2, ymm2, ymm3
	vandpd ymm2, ymm2, [WasSet]
	vorpd ymm2, ymm2, ymm4

	vmovapd [ActualIterations], ymm2

	pextrd eax, xmm3, 0
	mov rsi, -1
	cmp eax, 0 ;; Set first one when greater than threashold
	je NotSet1
	mov rsi, 0

NotSet1:
	pinsrq xmm2, rsi, 0

	pextrd eax, xmm3, 2
	mov rsi, -1
	cmp eax, 0 ;; Set second one when greater than threashold
	je NotSet2
	mov rsi, 0

NotSet2:
	pinsrq xmm2, rsi, 1

	vextracti128 xmm4, ymm3, 1
	 
	pextrd eax, xmm4, 0
	mov rsi, -1
	cmp eax, 0 ;; Set third one when greater than threashold
	je NotSet3
	mov rsi, 0

NotSet3:
	pinsrq xmm5, rsi, 0

	pextrd eax, xmm4, 2 
	mov rsi, -1
	cmp eax, 0 ;; Set fourth one when greater than threashold
	je NotSet4
	mov rsi, 0

NotSet4:
	pinsrq xmm5, rsi, 1

	vinserti128 ymm2, ymm2, xmm5, 1; merge xmm2 and xmm5 to ymm2, which creates was set mask
	vmovapd [WasSet], ymm2

	vhaddpd ymm2, ymm2, ymm2
	pextrq rax, xmm2, 0
	vextracti128 xmm2, ymm2, 1
	pextrq rsi, xmm2, 0
	add rax, rsi
	cmp rax, 0
	je IterLoop_esc

	;xmm2 1 0
	;xmm5 3 2
	;check if all were set, if yes jump(actually just move further) out to _esc

	inc r10d
	cmp r10d, r11d
	jl IterLoop

IterLoop_esc:

	;=======================================================
	;Coloring

	vmovapd ymm2, [ActualIterations]
	;STEP 1: Remap actual iterations from 0-MaxTterations to 0-1 floating point
	;ymm2 = toLow + (ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)

	;(ymm2 - fromLow) = ymm2
	;vxorpd ymm0, ymm0, ymm0; ymm0 = 0 - > fromLow		;
	;vsubpd ymm2, ymm2, ymm0; ymm2 = values - fromLow	; In our case always value - 0 so skipping these steps

	;(toHigh - toLow) = ymm3
	;vmovapd ymm3, ymmword [Ones]; ymm3 = 1.0 -> toHigh	;
	;vsubpd ymm3, ymm3, ymm0							; again 1 - 0 is 1 always

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

	vmovupd ymmword ptr[rdx], ymm3 ; save two pixels data and move pointer and load data for next two	
	add rdx, 32

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

	add rdx, 32
	
	add rcx, 32
	dec r9d
	jnz MainLoop

	ret
JuliaAsm endp
end