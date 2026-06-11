function imgDisp = enhance_inverse_display(img)

imgDisp = mat2gray(img);
imgDisp = imadjust(imgDisp, stretchlim(imgDisp,[0.01 0.99]), []);

end