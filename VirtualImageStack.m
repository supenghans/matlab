classdef VirtualImageStack < handle
    %IMAGESTACK A convenience class for saving sets of images.
    %
    %   Images are stored on disk; note all images are assumed to be the
    %   same size and have the same bitdepth.
    %
    %   EXAMPLE:
    %       extension = 'tiff';
    %       stack = ImageStack('my/directory', extension);
    %
    %   NOTE: The stack assumes that all images in the specified relpath with
    %   the specified extension are in the stack.
    
    properties (SetAccess = private)
        folder
        relpath
    end
    
    properties (Hidden, SetAccess = private)
        filetype        
        count
        rect
    end

    methods
        function obj = VirtualImageStack(relpath, filetype)
            obj.relpath = relpath;                        
            obj.folder = lowest_folder_from_path(obj.relpath, filesep);
            obj.filetype = filetype;
            obj.count = 0;
            %obj.rect = 0; % i.e there is no cropping
            [~, ~, ~] = mkdir(obj.relpath);
        end

        function img_name = push(self, img)
        %PUSH Add another image to the stack.

            img_name = self.next_name();
            save_location = fullfile(self.relpath, img_name);
            imwrite(img, save_location);
            self.count = self.count + 1;
        end

        function img_names = push3d(self, img_as_3d)
        %PUSH3D Add a 3D array of images to the stack.
        % Images are assumed to be indexed along the 3rd dimentions.
        % E.g.
        %     stack = VirtualImageStack('my/dir', 'png');
        %     img_as_3d = ones(800, 600, 10);
        %     stack.push3d(img_as_3d);

            [~, ~, nz] = size(img_as_3d);
            img_names = cell(nz);
            for img_count = 1:nz
                img_names{nz} = self.push(img_as_3d(:, :, img_count));
            end
        end

        function movie = movie(self, varargin)
        %MOVIE Generate an AVI movie from the virtual image stack.
        %
        %   The first argument is a string specifying the colormap;
        %   defaults to gray.  See COLORMAP for available colormaps.
        %
        %   Example:
        %       fps = 30;
        %       repeat = 5;
        %       cmap = 'jet';
        %       M = stack.movie(cmap);
        %       movie(M, repeat, fps);
        %
        %   See also MOVIE.

            if length(varargin) >= 1
                cmap = varargin{1};
            else
                cmap = 'gray';
            end

            bitdepth = self.bitdepth();
            cmap_size = 2^bitdepth;
            cmap = eval([cmap, '(', num2str(cmap_size), ');']);

            imgs = self.create_iterator();
            movie(imgs.length) = struct('cdata',[],'colormap',[]);
            for i = 1:imgs.length
                img = imgs.next();
                movie(i) = im2frame(img, cmap);
            end
        end
        
        function crop(self, rect)
        %CROP Crop out a portion of the images.
        %
        % rect is a four-element position vector[xmin ymin width height]
        % that specifies the size and position of the crop rectangle.
        %
        % Doesn't affect the underlying files, only the files that are read
        % in.  The area is simply a matlab slice
            self.rect = rect;
            % TODO: finish implimenting this
   
        end
        
        function sum = sum(self, mask)
        %SUM Sum all the images in the stack.
        %
        % Each images is cast to a double first to avoid overflow problems.
        %
        % There is an optional second argument, which is an array of
        % integers which selects which images to sum over.

            imgs = self.create_iterator();

            if ~exist('mask', 'var')
                mask = 1:imgs.length;
            end

            sum = double(imgs.next());
            img_num = 1;
            while(imgs.more())
                img = double(imgs.next());
                if ismember(img_num, mask)
                    sum = sum + img;
                end
                img_num = img_num + 1;
            end
        end

        function mean = mean(self, mask)
        %MEAN Mean of the images in the stack.
        %
        % Each images is cast to a double first to avoid overflow problems.
        %
        % There is an optional second argument, which is an array of
        % integers which selects which images to sum over.

            num_imgs = self.length();

            if ~exist('mask', 'var')
                mask = 1:num_imgs;
            end

            sum = self.sum(mask);
            mean = sum/num_imgs;
        end

        function iterator = create_iterator(self)
            glob = ['*.', self.filetype];
            iterator = ImageIterator(self.relpath, glob);
        end

        function bitdepth = bitdepth(self)
            first_img_name = self.create_file_iterator().next();
            info = imfinfo(first_img_name);
            bitdepth = info.BitDepth;
        end

        % TODO: handle case when stack is empty
        function shape = size(self)
            first_img = self.create_iterator().next();
            shape = size(first_img);
        end

        function length = length(self)
            length = self.create_iterator().length;
        end

        function clear(self)
        %CLEAR Delete all images and reset image counter.

            iter = self.create_file_iterator();
            while(iter.more())
                delete(iter.next());
            end
            self.count = 0;
        end
    end


    methods (Access = private)

        function iterator = create_file_iterator(self)
            glob = ['*.', self.filetype];
            iterator = FileIterator(self.relpath, glob);
        end

        function img_name = next_name(self)
            count_as_str = sprintf('%4.4d', self.count);
            img_name = ['img', count_as_str, '.', self.filetype];
        end

        function test_img = test_image(self)
            imgs = self.create_iterator();
            if imgs.more()
                test_img = imgs.next();
            else
                test_img = [];
            end
        end

    end

end
