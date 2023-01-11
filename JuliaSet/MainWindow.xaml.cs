using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Policy;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;
using System.Windows.Navigation;
using System.Windows.Shapes;
using static System.Net.Mime.MediaTypeNames;

namespace JuliaSet
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        [DllImport("AsmDll.dll")]
        private static unsafe extern void JuliaAsm(ComplexCoord* inCoord, Pixel* outBMP, UserSettings settings);
        [DllImport("CDll.dll")]
        private static unsafe extern void JuliaCpp(ComplexCoord* inCoord, Pixel* outBMP, UserSettings settings);

        public struct Pixel
        {
            public float r; //32-bits
            public float g;
            public float b;
            public float a;
            public Pixel()
            {
                r = 255;
                g = 255;
                b = 255;
                a = 255;
            }
        }
        public struct ComplexCoord
        {
            public float x; //32-bits
            public float y; //      
        }

        public struct UserSettings
        {
            public float c_real;
            public float c_imag;
            public int size;
            public int maxIter;
            public UserSettings(float c_r, float c_im, int size, int maxIter)
            {
                c_real = c_r;
                c_imag = c_im;
                this.size = size;
                this.maxIter = maxIter;
            }
        }
        ComplexCoord[] newComplexCoord;
        ComplexCoord[] newComplexCoordCPP;
        ComplexCoord[] newComplexCoordASM;
        UserSettings settings;


        Pixel[] outBMP;
        Pixel[] outBMPASM;
        Pixel[] outBMPCPP;

        int width;
        int height;
        int size;
        int numRuns;

        float zoomV;
        public MainWindow()
        {
            InitializeComponent();
            numRuns = 10;
            zoomV = 1.5f;

            width = (int)image.Width;
            height = (int)image.Height;

            /*            int width = 50;
                        int height = 50;*/
            size = width * height;

            newComplexCoord = new ComplexCoord[size];
            newComplexCoordCPP = new ComplexCoord[size];
            newComplexCoordASM = new ComplexCoord[size];
            settings = new UserSettings(-0.8f, 0.156f, size, 250);


            outBMP = new Pixel[width * height];
            outBMPASM = new Pixel[width * height];
            outBMPCPP = new Pixel[width * height];

            for (int i = 0; i < size; i++) outBMP[i] = new Pixel();
            for (int i = 0; i < size; i++) outBMPASM[i] = new Pixel();
            for (int i = 0; i < size; i++) outBMPCPP[i] = new Pixel();

            //==============================

            //TESTING ====================================
            /*
                        ComplexCoord[] testASM = new ComplexCoord[size];
                        ComplexCoord[] testCPP = new ComplexCoord[size];
                        for (int i = 0; i < size; i++) testASM[i] = newComplexCoord[8156];
                        for (int i = 0; i < size; i++) testCPP[i] = newComplexCoord[8156];
                        UserSettings testSettings = new UserSettings(-0.8f, 0.156f, size, 255);

                        unsafe
                        {
                            fixed (Pixel* outBMPAddr = outBMPCPP)
                            {
                                fixed (ComplexCoord* newCoordCPPAddr = testCPP)
                                {
                                    JuliaCpp(newCoordCPPAddr, outBMPAddr, testSettings);
                                }
                            }
                        }

                        unsafe
                        {
                            fixed (ComplexCoord* cordAddr = testASM)
                            {
                                fixed (Pixel* outBMPAddr = outBMPASM)
                                {
                                    JuliaAsm(cordAddr, outBMPAddr, testSettings);
                                }
                            }
                        }

                        for(int i = 0; i < size; i++)
                        {
                            if (outBMPCPP[i].r != outBMPASM[i].r) throw new Exception();
                        }            
            */
            //============================================


        }
        public void InitData(ComplexCoord[] inComplexCoord, int width, int height)
        {
            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
                {
                    inComplexCoord[y * width + x].x = Remap(x, 0, width, -zoomV, zoomV);
                    inComplexCoord[y * width + x].y = Remap(y, 0, height, -zoomV, zoomV);
                }
            }
        }

        public static void JuliaSet(ComplexCoord[] inComplexCoord, Pixel[] outBMP, UserSettings settings)
        {
            //Z = Z^2 + C

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
                    float aa = inComplexCoord[i].x * inComplexCoord[i].x;
                    float bb = inComplexCoord[i].y * inComplexCoord[i].y;

                    //COMPUTE NEXT
                    //Z = Z^2 + C

                    //Z^2
                    float newReal = aa - bb; // new Z^2 real part
                    float newImag = 2 * inComplexCoord[i].x * inComplexCoord[i].y; // new Z^2 imaginary part

                    //Z = Z^2 + C, Z = a + bi, so Z = Z^2 + C is Z = (aa + ca) + (bb + cb)i
                    inComplexCoord[i].x = newReal + ca; //Z real 
                    inComplexCoord[i].y = newImag + cb;

                    //Condition for determaining if the Z for given coordinates is bounded, can be adjusted
                    if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
                    {
                        break;
                    }
                }

                //Nice gray scale coloring

                if (n == maxIterations)
                {
                    outBMP[i].r = 0;
                    outBMP[i].g = 0;
                    outBMP[i].b = 0;
                }
                else
                {
                    float val = Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                    outBMP[i].r = val;
                    outBMP[i].g = val;
                    outBMP[i].b = val;
                }
            }
        }

        private static float Remap(float source, float sourceFrom, float sourceTo, float targetFrom, float targetTo)
        {
            return targetFrom + (source - sourceFrom) * (targetTo - targetFrom) / (sourceTo - sourceFrom);
        }

        BitmapImage BitmapToImageSource(Bitmap bitmap)
        {
            using (MemoryStream memory = new MemoryStream())
            {
                bitmap.Save(memory, System.Drawing.Imaging.ImageFormat.Bmp);
                memory.Position = 0;
                BitmapImage bitmapimage = new BitmapImage();
                bitmapimage.BeginInit();
                bitmapimage.StreamSource = memory;
                bitmapimage.CacheOption = BitmapCacheOption.OnLoad;
                bitmapimage.EndInit();

                return bitmapimage;
            }
        }

        private void maxIter_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            settings.maxIter = (int)maxIter.Value;
        }

        private void runNum_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            numRuns = (int)runNum.Value;
        }

        private void cReal_TextChanged(object sender, TextChangedEventArgs e)
        {
            if(cReal.Text != "-" && cReal.Text != "+" && cReal.Text != "")
                settings.c_real = float.Parse(cReal.Text);
        }

        private void zoom_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            zoomV = (float)zoom.Value;
        }
        private void cImag_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (cImag.Text != "-" && cImag.Text != "+" && cImag.Text != "")
                settings.c_imag = float.Parse(cImag.Text);
        }

        private void NumberValidationTextBox(object sender, TextCompositionEventArgs e)
        {
            Regex regex = new Regex("[^0-9]+");
            e.Handled = regex.IsMatch(e.Text);
        }

        private void button_Click(object sender, RoutedEventArgs e)
        {
            var watch = new System.Diagnostics.Stopwatch();
            float time = 0.0f;
            for (int i = 0; i < numRuns; i++)
            {
                InitData(newComplexCoord, width, height);
                watch.Start();
                JuliaSet(newComplexCoord, outBMP, settings);
                watch.Stop();
                time += watch.ElapsedMilliseconds;
            }
            time = time / 10;
            cTime.Text = time.ToString() + "ms.";

            //==============================
            time = 0;
            unsafe
            {
                fixed (ComplexCoord* cordAddr = newComplexCoordASM)
                {
                    fixed (Pixel* outBMPAddr = outBMPASM)
                    {
                        InitData(newComplexCoordASM, width, height);
                        JuliaAsm(cordAddr, outBMPAddr, settings);
                        for (int i = 0; i < numRuns; i++)
                        {
                            InitData(newComplexCoordASM, width, height);
                            watch.Start();
                            JuliaAsm(cordAddr, outBMPAddr, settings);
                            watch.Stop();
                            time += watch.ElapsedMilliseconds;
                        }
                    }
                }
            }

            time = time / 10;
            asmTime.Text = time.ToString() + "ms.";
            time = 0;
            unsafe
            {
                fixed (Pixel* outBMPAddr = outBMPCPP)
                {
                    fixed (ComplexCoord* newCoordCPPAddr = newComplexCoordCPP)
                    {
                        InitData(newComplexCoordCPP, width, height);
                        JuliaCpp(newCoordCPPAddr, outBMPAddr, settings);
                        for (int i = 0; i < numRuns; i++)
                        {
                            InitData(newComplexCoordCPP, width, height);
                            watch.Start();
                            JuliaCpp(newCoordCPPAddr, outBMPAddr, settings);
                            watch.Stop();
                            time += watch.ElapsedMilliseconds;
                        }
                    }
                }
            }

            time = time / 10;
            cppTime.Text = time.ToString() + "ms.";

            for (int i = 0; i < size; i++)
            {
                outBMPCPP[i].r = outBMPCPP[i].r < 255 ? outBMPCPP[i].r : 255;
                outBMPCPP[i].g = outBMPCPP[i].g < 255 ? outBMPCPP[i].g : 255;
                outBMPCPP[i].b = outBMPCPP[i].b < 255 ? outBMPCPP[i].b : 255;
            }

            for (int i = 0; i < size; i++)
            {
                outBMPASM[i].r = outBMPASM[i].r < 255 ? outBMPASM[i].r : 255;
                outBMPASM[i].g = outBMPASM[i].g < 255 ? outBMPASM[i].g : 255;
                outBMPASM[i].b = outBMPASM[i].b < 255 ? outBMPASM[i].b : 255;
            }

            Bitmap bitmap = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
            System.Drawing.Color pixelColor;

            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb(255, (int)outBMPCPP[y * width + x].r, (int)outBMPCPP[y * width + x].g, (int)outBMPCPP[y * width + x].b);
                    bitmap.SetPixel(x, y, pixelColor);
                }

            //bitmap.Save("../../../JuliaSet/images/Set.png");

            Bitmap bitmapASM = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb(255, (int)outBMPASM[y * width + x].r, (int)outBMPASM[y * width + x].g, (int)outBMPASM[y * width + x].b);
                    bitmapASM.SetPixel(x, y, pixelColor);
                }

            image.Source = BitmapToImageSource(bitmap);
            image2.Source = BitmapToImageSource(bitmapASM);

            //bitmapASM.Save("../../../JuliaSet/images/Set2.png");

            //image.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSetCppCsAsm\\JuliaSet\\images\\Set.png", UriKind.Absolute));
            //image2.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSetCppCsAsm\\JuliaSet\\images\\Set2.png", UriKind.Absolute));

        }
    }
}
