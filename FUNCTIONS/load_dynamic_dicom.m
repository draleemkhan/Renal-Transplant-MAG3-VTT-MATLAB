function [img, info] = load_dynamic_dicom(dicomFile)

% Load DICOM metadata
info = dicominfo(dicomFile, 'UseDictionaryVR', true);

% Load image data
img = squeeze(dicomread(dicomFile));
img = double(img);

% Check that this is a dynamic 3D image series
if ndims(img) ~= 3
    error('Selected DICOM is not a 3D dynamic image series.');
end

end