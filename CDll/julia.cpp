#include "pch.h"
#include "julia.h"
#include <cmath>

float Remap(float source, float sourceFrom, float sourceTo, float targetFrom, float targetTo)
{
    return targetFrom + (source - sourceFrom) * (targetTo - targetFrom) / (sourceTo - sourceFrom);
}

void JuliaCpp(ComplexCoord* inCoord, Pixel* outBMP, UserSettings settings) {
    int maxIterations = settings.maxIter;

    //C = ca + cb*i
    float ca; //C real part
    float cb; //C imaginary part
    //Z = a+b*i
    //double a; //Z real part 
    //double b; //Z imaginary part

    for (int i = 0; i < settings.size; ++i)
    {
        //For each pixel coordinate
        //ca = inComplexCoord[i].x; // C real part is equal to the real part mapped from coordinates
        //cb = inComplexCoord[i].y; // C imaginary part is equal to the real part mapped from coordinates

        // When instead of having different C number for each pixel we asign it to specific number for all pixels we get Julia Set.
        ca = settings.c_real;
        cb = settings.c_imag;
        int n = 0;

        for (; n < maxIterations; ++n)
        {
            float aa = inCoord[i].x * inCoord[i].x;
            float bb = inCoord[i].y * inCoord[i].y;

            //COMPUTE NEXT
            //Z = Z^2 + C

            //Z^2
            float newReal = aa - bb; // new Z^2 real part
            float newImag = 2 * inCoord[i].x * inCoord[i].y; // new Z^2 imaginary part

            //Z = Z^2 + C, Z = a + bi, so Z = Z^2 + C is Z = (aa + ca) + (bb + cb)i
            inCoord[i].x = newReal + ca; //Z real 
            inCoord[i].y = newImag + cb;

            //Condition for determaining if the Z for given coordinates is bounded, can be adjusted
            if (abs(inCoord[i].x + inCoord[i].y) > 16)
            {
                break;
            }
        }

        //Nice gray scale coloring, we can do it with actual colors, also doesn't matter for logic part 

        if (n == maxIterations)
        {
            outBMP[i].r = 0;
            outBMP[i].g = 0;
            outBMP[i].b = 0;
        }
        else
        {
            float val = Remap((float)sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
            outBMP[i].r = val;
            outBMP[i].g = val;
            outBMP[i].b = val;
        }
       /* else{
            outBMP[i].r = n;
            outBMP[i].g = n;
            outBMP[i].b = n;
        }*/
    }
}