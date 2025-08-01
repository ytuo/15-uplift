import requests
import time
import zipfile
import glob

def download_file_with_progress(url, local_filename=None, download_dir="data/coc-shapefiles"):
    """
    Download a file with progress tracking
    """
    # Create download directory
    os.makedirs(download_dir, exist_ok=True)
    
    # Extract filename from URL if not provided
    if local_filename is None:
        parsed_url = urlparse(url)
        local_filename = os.path.basename(parsed_url.path)
    
    # Full path for the file
    file_path = os.path.join(download_dir, local_filename)
    
    print(f"Downloading: {url}")
    print(f"Saving to: {file_path}")
    print("-" * 50)
    
    try:
        # Start the download
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()  # Raise an exception for bad status codes
        
        # Get file size if available
        total_size = int(response.headers.get('content-length', 0))
        
        # Download the file
        downloaded_size = 0
        start_time = time.time()
        
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded_size += len(chunk)
                    
                    # Show progress
                    if total_size > 0:
                        percent = (downloaded_size / total_size) * 100
                        speed = downloaded_size / (time.time() - start_time) / 1024 / 1024  # MB/s
                        print(f"\rProgress: {percent:.1f}% ({downloaded_size/(1024*1024):.1f}/{total_size/(1024*1024):.1f} MB) - Speed: {speed:.1f} MB/s", end='')
                    else:
                        print(f"\rDownloaded: {downloaded_size/(1024*1024):.1f} MB", end='')
        
        # Final stats
        total_time = time.time() - start_time
        final_size = downloaded_size / (1024 * 1024)  # Convert to MB
        avg_speed = final_size / total_time if total_time > 0 else 0
        
        print(f"\n✅ Download complete!")
        print(f"File size: {final_size:.1f} MB")
        print(f"Time taken: {total_time:.1f} seconds")
        print(f"Average speed: {avg_speed:.1f} MB/s")
        print(f"Saved to: {os.path.abspath(file_path)}")
        
        return file_path
        
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Download failed: {str(e)}")
        return None
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        return None

def download_coc_state_file(state_code, year, download_dir="data/coc-shapefiles"):
    """
    Download CoC state shapefile using the pattern from your URL
    """
    url = f"https://files.hudexchange.info/reports/published/CoC_GIS_State_Shapefile_{state_code}_{year}.zip"
    filename = f"CoC_GIS_State_Shapefile_{state_code}.zip"
    
    return download_file_with_progress(url, filename, download_dir + "/" + str(year))

def unzip_all(folder_path):
    """
    Unzip all .zip files in a folder
    """
    zip_files = glob.glob(os.path.join(folder_path, "*.zip"))
    
    for zip_file in zip_files:
        # Create folder name without .zip extension
        extract_to = os.path.splitext(zip_file)[0]
        
        try:
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                zip_ref.extractall(extract_to)
            print(f"✅ Extracted: {os.path.basename(zip_file)}")
        except Exception as e:
            print(f"❌ Failed: {os.path.basename(zip_file)} - {e}")