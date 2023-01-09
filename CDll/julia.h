#pragma once
struct Pixel
{
    float r; //32-bits
    float g;
    float b;
    float a;
};

struct UserSettings
{
    float c_real;
    float c_imag;
    int size;
    int maxIter;
};

struct ComplexCoord
{
    float x; //32-bits  xxxxxxxxxxxxxxxx... xxxx yyyyyyyy...yyyy
    float y; //    
};

extern "C" __declspec(dllexport) void JuliaCpp(ComplexCoord* inCoord, Pixel * outBMP, UserSettings settings);