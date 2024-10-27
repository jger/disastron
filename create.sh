#!/bin/bash

# Function to generate a random SVG logo with specified dimensions
generate_svg_logo() {
  local app_name=$1
  local color=$2
  local svg_file=$3

  # Split the app name into multiple lines if it is more than 6 characters
  if [ ${#app_name} -gt 6 ]; then
    if [[ "$app_name" == *" "* ]]; then
      app_name=$(echo "$app_name" | tr ' ' '\n')
    else
      app_name=$(echo "$app_name" | fold -w 5 | tr ' ' '\n')
    fi
  fi

  # Generate first random shape properties
  local shape_type1=$((RANDOM % 3))
  local shape_color1=$(printf "#%02X%02X%02X%02X\n" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) 128)
  local shape1

  case $shape_type1 in
    0) # Circle
      shape1="<circle cx='512' cy='512' r='256' fill='$shape_color1' />"
      ;;
    1) # Rectangle
      shape1="<rect x='256' y='256' width='512' height='512' fill='$shape_color1' />"
      ;;
    2) # Ellipse
      shape1="<ellipse cx='512' cy='512' rx='256' ry='128' fill='$shape_color1' />"
      ;;
  esac

  # Generate second random shape properties
  local shape_type2=$((RANDOM % 3))
  local shape_color2=$(printf "#%02X%02X%02X%02X\n" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) 102)
  local shape2

  case $shape_type2 in
    0) # Circle
      shape2="<circle cx='512' cy='512' r='128' fill='$shape_color2' />"
      ;;
    1) # Rectangle
      shape2="<rect x='384' y='384' width='256' height='256' fill='$shape_color2' />"
      ;;
    2) # Ellipse
      shape2="<ellipse cx='512' cy='512' rx='128' ry='64' fill='$shape_color2' />"
      ;;
  esac

  # Create the SVG content
  cat <<EOF > $svg_file
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
  <rect width="1024" height="1024" fill="$color"/>
  $shape1
  $shape2
  <text x="50%" y="50%" font-family="Arial" font-size="200" font-weight="bold" fill="white" text-anchor="middle" alignment-baseline="middle">
EOF

  # Add each line of the app name as a separate <tspan> element
  local y_offset=0
  while IFS= read -r line; do
    echo "    <tspan x='50%' dy='$y_offset'>$line</tspan>" >> $svg_file
    y_offset="0.8em"
  done <<< "$app_name"

  # Close the SVG content
  cat <<EOF >> $svg_file
  </text>
</svg>
EOF
}

# Function to convert SVG to PNG
convert_svg_to_png() {
  local svg_file=$1
  local png_file=$2

  if command -v magick &> /dev/null; then
    magick convert $svg_file $png_file
  else
    echo "ImageMagick is not installed. Please install it to convert SVG to PNG."
    echo "You can install it using:"
    echo "brew install imagemagick"
    exit 1
  fi
}

# Function to generate a random color with low brightness
generate_random_color() {
  while : ; do
    local color=$(printf "#%02X%02X%02X\n" $((RANDOM % 128)) $((RANDOM % 128)) $((RANDOM % 128)))
    echo $color
    break
  done
}

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
  echo "ImageMagick is not installed. Please install it to proceed."
  echo "You can install it using:"
  echo "brew install imagemagick"
  exit 1
fi

# Ask for app name and primary color
read -p "Enter the app name: " app_name
read -p "Enter the primary app color (#rrggbb, hit enter for random): " app_color

# Assign a random color if the user hits enter
if [ -z "$app_color" ]; then
  while : ; do
    app_color=$(generate_random_color)
    # Ensure the random color is different from the font color (white)
    if [ "$app_color" != "#FFFFFF" ]; then
      break
    fi
  done
  echo "Random color assigned: $app_color"
fi

# Create assets/images directory if it doesn't exist
mkdir -p ./assets/images

# Always generate SVG logo
svg_logo="./assets/images/logo.svg"
generate_svg_logo "$app_name" "$app_color" "$svg_logo"

# Ask if the user wants to override existing files
read -p "Do you want to override the existing splash? (Y/n): " override_splash
override_splash=${override_splash:-Y}
read -p "Do you want to override the existing launcher icon? (Y/n): " override_launcher
override_launcher=${override_launcher:-Y}

# Convert SVG to PNG for splash and launcher icons if user agrees to override
png_splash="./assets/images/splash.png"
png_launcher="./assets/images/launch.png"
if [ "$override_splash" == "Y" ]; then
  convert_svg_to_png "$svg_logo" "$png_splash"
fi
if [ "$override_launcher" == "Y" ]; then
  convert_svg_to_png "$svg_logo" "$png_launcher"
fi

echo "SVG logo and PNG files have been created in ./assets/images"