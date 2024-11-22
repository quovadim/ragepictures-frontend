import React, { useState } from "react";

const App = () => {
  const [file, setFile] = useState(null); // Store selected file
  const [previewImage, setPreviewImage] = useState(null); // Preview of uploaded image
  const [resultImage, setResultImage] = useState(null); // Store swapped image URL
  const [error, setError] = useState(null); // Handle errors
  const [isUploading, setIsUploading] = useState(false); // Handle upload status

  const handleFile = (file) => {
    const allowedExtensions = ["image/jpeg", "image/png", "image/webp"];
    if (file && allowedExtensions.includes(file.type)) {
      setFile(file);
      setError(null);

      // Generate preview
      const reader = new FileReader();
      reader.onload = () => setPreviewImage(reader.result); // Show preview
      reader.readAsDataURL(file);
    } else {
      setError("Please upload a valid image (JPEG, PNG, or WebP).");
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    handleFile(selectedFile);
  };

  const handlePaste = (e) => {
    const items = e.clipboardData.items;
    for (const item of items) {
      if (item.type.startsWith("image/")) {
        const blob = item.getAsFile();
        handleFile(blob);
        break; // Only process the first image
      }
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!file) {
      setError("Please select or paste an image before uploading.");
      return;
    }
  
    setIsUploading(true);
    const formData = new FormData();
    formData.append("image", file);
  
    try {
      const API_URL = process.env.REACT_APP_API_URL || "http://backend:5050";
  
      // Log the API endpoint and request details
      console.log("Sending POST request to:", `${API_URL}/swap`);
      console.log("FormData entries:");
      for (let [key, value] of formData.entries()) {
        if (value instanceof File) {
          console.log(`${key}: File - Name: ${value.name}, Size: ${value.size}, Type: ${value.type}`);
        } else {
          console.log(`${key}: ${value}`);
        }
      }
  
      const response = await fetch(`${API_URL}/swap`, {
        method: "POST",
        body: formData,
      });
  
      // Log the response headers
      console.log("Response status:", response.status);
      console.log("Response headers:", [...response.headers.entries()]);
  
      if (!response.ok) {
        throw new Error(`Failed to upload image. Status: ${response.status}`);
      }
  
      const blob = await response.blob(); // Parse the image response
      const imageUrl = URL.createObjectURL(blob); // Create a URL for the Blob
      console.log("Received image URL:", imageUrl);
  
      setResultImage(imageUrl); // Set the image for rendering
    } catch (err) {
      console.error("Error occurred during request:", err.message);
      setError(err.message);
    } finally {
      setIsUploading(false);
    }
  };
  

  const resetForm = () => {
    setFile(null);
    setPreviewImage(null);
    setResultImage(null);
    setError(null);
  };

  return (
    <div
      className="min-h-screen bg-greyDark text-white flex flex-col items-center justify-center p-4"
      onPaste={handlePaste} // Listen for paste events on the entire container
    >
      {/* Header */}
      <header className="bg-black w-full py-6 text-center shadow-md relative">
        <h1 className="text-4xl font-extrabold text-naziRed tracking-wide mb-10">
          Shows Who Was Nazi All That Time!
        </h1>
        <div className="relative">
          {/* Sentence 1 */}
          <p className="text-lg text-white font-semibold transform rotate-3 mb-6">
            Got into a heated argument and have nothing more to say?
          </p>

          {/* Sentence 2 */}
          <p className="text-lg text-white font-semibold transform -rotate-2 mb-6">
            Want to show who is the boss here?
          </p>

          {/* Sentence 3 */}
          <p className="text-lg text-white font-semibold transform rotate-1 mb-6">
            Want to make your opponent cry and crawl back to you with apologies?
          </p>

          {/* Sentence 4 */}
          <p className="text-lg text-naziRed font-bold transform -rotate-1">
            Here is the final solution: just upload their photo, and we'll do everything for you.
          </p>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-grow flex flex-col items-center justify-center w-full">
        <div className="w-full max-w-3xl bg-greyLight shadow-lg rounded-lg p-6">
          {resultImage ? (
            <div className="text-center">
              <h2 className="text-lg font-semibold mb-4 text-naziRed">Result:</h2>
              <img
                src={resultImage}
                alt="Swapped"
                className="my-4 max-w-full rounded-lg shadow-md mx-auto"
              />
              <div className="flex justify-center space-x-4 mt-4">
                <button
                  onClick={() => window.open(resultImage, "_blank")}
                  className="px-4 py-2 bg-naziRed text-white rounded-lg shadow hover:bg-red-700"
                >
                  Download
                </button>
                <button
                  onClick={resetForm}
                  className="px-4 py-2 bg-black text-white rounded-lg shadow hover:bg-gray-700"
                >
                  Generate Another One
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="flex flex-col items-center">
              <p className="mb-4 text-muted">
                Choose an image (JPEG, PNG, or WebP) to swap faces, or <span className="text-naziRed">paste</span> one directly!
              </p>
              <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="mb-4 p-2 border rounded-md bg-greyLight text-white"
              />
              {previewImage && (
                <div className="mb-4">
                  <h2 className="text-lg font-semibold mb-2 text-naziRed">Preview:</h2>
                  <img
                    src={previewImage}
                    alt="Uploaded Preview"
                    className="max-w-full rounded-lg shadow-md mx-auto"
                  />
                </div>
              )}
              {error && <p className="text-red-500 mb-2">{error}</p>}
              <button
                type="submit"
                className={`px-6 py-2 bg-naziRed text-white rounded-lg shadow ${
                  isUploading ? "opacity-50" : "hover:bg-red-700"
                }`}
                disabled={isUploading}
              >
                {isUploading ? "Processing..." : "Upload and Swap"}
              </button>

              {/* Disclaimer */}
              <p className="text-sm text-muted text-center mt-8 max-w-lg leading-relaxed">
                <span className="text-naziRed font-bold">Heads up:</span> We don’t take any responsibility for what you upload or how you use the results. If someone gets mad or offended, that’s totally on you—so, use this responsibly!
              </p>
            </form>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="text-center py-4 text-muted text-sm">
        © 2024 I have nothing to do Foundation. No rights reserved.
      </footer>
    </div>
  );
};

export default App;
