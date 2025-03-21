import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [prompt, setPrompt] = useState('');
  const [generatedCode, setGeneratedCode] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [previewHtml, setPreviewHtml] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    
    try {
      const response = await fetch('http://localhost:8000/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt: prompt,
          max_tokens: 1000,
        }),
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.detail || 'Failed to generate code');
      }
      
      setGeneratedCode(data.response);
      
      if (prompt.toLowerCase().includes('html') || 
          prompt.toLowerCase().includes('web') || 
          prompt.toLowerCase().includes('ui') ||
          prompt.toLowerCase().includes('react')) {
        preparePreview(data.response);
      }
    } catch (error) {
      setError(error.message);
    } finally {
      setIsLoading(false);
    }
  };
  
  const preparePreview = (code) => {
    let htmlContent = code;
    
    if (code.includes('<html>') || code.includes('<body>') || code.includes('<div>')) {
      htmlContent = code;
    } 
    else if (code.includes('import React') || code.includes('function') || code.includes('const') || code.includes('return')) {
      htmlContent = `
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; padding: 20px; }
          </style>
        </head>
        <body>
          <div id="root">
            <p>React code detected! In a real implementation, this would be rendered through a React renderer.</p>
            <pre>${code.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
          </div>
        </body>
        </html>
      `;
    }
    
    setPreviewHtml(htmlContent);
  };
  
  const handleTrainingUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    
    const formData = new FormData();
    formData.append('file', file);
    
    setIsLoading(true);
    setError('');
    
    try {
      const response = await fetch('http://localhost:8000/upload-examples', {
        method: 'POST',
        body: formData,
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.detail || 'Failed to upload training examples');
      }
      
      alert(`Training completed successfully with ${data.examples_trained} examples!`);
    } catch (error) {
      setError(error.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="app-container">
      <header>
        <h1>ZeroCode AI App Generator</h1>
        <p>Describe the app or feature you want to build</p>
      </header>

      <main>
        <div className="control-panel">
          <form onSubmit={handleSubmit}>
            <textarea
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="Describe the app or feature you want to create... (e.g., 'Create a simple to-do list app with HTML, CSS, and JavaScript')"
              rows={5}
              required
            />
            <button type="submit" disabled={isLoading}>
              {isLoading ? 'Generating...' : 'Generate Code'}
            </button>
          </form>
          
          <div className="training-section">
            <h3>Train with Examples</h3>
            <p>Upload a JSON file with prompt-completion pairs to fine-tune the model:</p>
            <input type="file" accept=".json" onChange={handleTrainingUpload} />
          </div>
        </div>

        {error && <div className="error-message">{error}</div>}

        <div className="result-container">
          <div className="code-section">
            <h2>Generated Code</h2>
            <pre><code>{generatedCode}</code></pre>
          </div>
          
          <div className="preview-section">
            <h2>Live Preview</h2>
            <div className="preview-frame">
              {previewHtml ? (
                <iframe
                  title="Code Preview"
                  srcDoc={previewHtml}
                  width="100%"
                  height="100%"
                  sandbox="allow-scripts"
                />
              ) : (
                <div className="no-preview">
                  <p>Generate code to see a preview</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </main>

      <footer>
        <p>Powered by ZeroCode • AI-Powered Code Generation</p>
      </footer>
    </div>
  );
}

export default App;