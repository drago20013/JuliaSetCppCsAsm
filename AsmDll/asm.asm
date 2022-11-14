.data
AlphaMask dd 3 dup (0ffffffffh), 0, 3 dup (0ffffffffh), 0
NotAlphaMask dd 3 dup (0), 0ffffffffh, 3 dup (0), 0ffffffffh
AAMask dd 4 dup(0ffffffffh, 0)
BBMask dd 4 dup(0, 0ffffffffh)
AbsMask dd 2 dup(0, 0, 07fffffffh, 07fffffffh)
WasSet dq 4 dup(-1)
Ones dd 8 dup(1)
Threashold real4 2 dup(0.0, 0.0, 16.0, 16.0)
JuliaConst real4 4 dup(-0.4, -0.59)

CRealPart real4 4 dup(?)
CImagPart real4 4 dup(?)
Twos real4 4 dup(0.0, 2.0)
ActualIterations dq 4 dup(0)
MaxIteration dd ?
.code
 ;CalculateMandelbrotASM(
 ;ComplexCoord* inCoord, RCX
 ;Pixel* outBMP,		 RDX
 ;int width,			 R8
 ;int height);			 R9
Dummy proc
  ret
Dummy endp
CalculateMandelbrotASM proc
	mov [MaxIteration], 255

	imul r9d, r8d
	shr r9d, 2
	mov r11d, [MaxIteration] ; counter
	
MainLoop:
	;do stuff
	vmovups	ymm0, ymmword ptr[rcx]
	;vmovaps ymm1, ymm0
	;julia c = -0.4 + -0.59
	vmovaps	ymm1, [JuliaConst]
	
	



	xor r10, r10

	mov rax, -1 
	vmovq xmm2,  rax
	vpbroadcastq ymm2, xmm2
	vmovapd [WasSet], ymm2
	mov rax, 0
	vmovq xmm2,  rax
	vpbroadcastq ymm2, xmm2
	vmovapd [ActualIterations], ymm2
IterLoop:
	;mov r10d, r8d ; to calculate actual iterations

	vmulps ymm3, ymm0, ymm0 ;a*a and b*b
	vmovaps ymm4, ymm3 ; duplicate

	vandps ymm2, ymm3, [AAMask] ; get a*a
	vandps ymm4, ymm4 ,[BBMask] ; get b*b

	vpshufd ymm2, ymm2, 93h ;not sure if this shit works

	vsubps ymm2, ymm2, ymm4 ;get aa = a*a - b*b
	
	;bb = 2*a*b
	vmovaps ymm3, ymm0 ; duplicate
	vmovaps ymm4, ymm0 ; duplicate ;already in ymm1 and ymm0

	vandps ymm3, ymm0, [BBMask] ; get b
	vandps ymm4, ymm4, [AAMask]; get a

	vpshufd ymm4, ymm4, 93h

	vmulps ymm6, ymm3, ymm4 ;a*b
	vmulps ymm6, ymm6, [Twos] ; bb = 2*a*b

	;merge aa and bb to ymm2
	vpshufd ymm2, ymm2, 39h
	vorps ymm2, ymm2, ymm6

	;Z = (aa+bb*i) + (ca+cb*i)
	vaddps ymm0, ymm1, ymm2

	; if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
	;a - ymm4
	;b - ymm3
	vhaddps ymm3, ymm0, ymm0 ; inComplexCoord[i].x + inComplexCoord[i].y
	;vmovaps ymm5, [AbsMask]
	vandps ymm3, ymm3, [AbsMask] ; Abs


	;vmovaps ymm5, [Threashold]
	
	;if larger break and save number of iterations--------
	
	vcmpgtps ymm3, ymm3, [Threashold]

	vpshufd ymm3, ymm3, 00110110b

	;sub r10d, r8d
	;sub r10d, 1
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
	;check if all were set, jump out to _esc

	inc r10d
	cmp r10d, r11d
	jl IterLoop

IterLoop_esc:

	vmovapd ymm2, [ActualIterations]
	;calculate each part of color and put it back to pixel
	vmovups	ymm0, ymmword ptr[rdx]
	vandps ymm0, ymm0, [NotAlphaMask]
	;first pixel
	vpbroadcastd ymm3, xmm2 
	vandps ymm3, ymm3, [AlphaMask]
	vorpd ymm3, ymm3, ymm0

	vextracti128 xmm0, ymm0, 1
	;second
	pextrq rax, xmm2, 1
	;mov rax, 6
	vmovq xmm1, rax
	vpbroadcastd ymm5, xmm1 
	vandps ymm5, ymm5, [AlphaMask]
	vorpd ymm5, ymm5, ymm0

	vinserti128 ymm3, ymm3, xmm5, 1

	vmovupd ymmword ptr[rdx], ymm3 ; save two pixels data and move pointer and load data for next two	
	add rdx, 32

	vmovups	ymm0, ymmword ptr[rdx]
	vandps ymm0, ymm0, [NotAlphaMask]
	vextracti128 xmm2, ymm2, 1
	;third
	vpbroadcastd ymm3, xmm2 
	vandps ymm3, ymm3, [AlphaMask]
	vorpd ymm3, ymm3, ymm0

	vextracti128 xmm0, ymm0, 1
	;second
	pextrq rax, xmm2, 1
	;mov rax, 7
	vmovq xmm1, rax
	vpbroadcastd ymm5, xmm1 
	vandps ymm5, ymm5, [AlphaMask]
	vorpd ymm5, ymm5, ymm0

	vinserti128 ymm3, ymm3, xmm5, 1

	vmovupd ymmword ptr[rdx], ymm3
	add rdx, 32
	
	add rcx, 32
	dec r9d
	jnz MainLoop

	ret
CalculateMandelbrotASM endp
end