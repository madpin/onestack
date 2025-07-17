
// Ensure summarize buttons are configured after DOM is ready
if (document.readyState && document.readyState !== 'loading') {
  configureSummarizeButtons();
} else {
  document.addEventListener('DOMContentLoaded', configureSummarizeButtons, false);
}

// Attach click event handler to the global container for summary button logic
function configureSummarizeButtons() {
  document.getElementById('global').addEventListener('click', function (e) {
    // Traverse up the DOM tree from the event target
    for (var target = e.target; target && target != this; target = target.parentNode) {
      // If a feed header is clicked, reset the summary button text
      if (target.matches('.flux_header')) {
        target.nextElementSibling.querySelector('.oai-summary-btn').innerHTML = 'Summarize'
      }

      // If a summary button is clicked, handle the summarize action
      if (target.matches('.oai-summary-btn')) {
        e.preventDefault();
        e.stopPropagation();
        if (target.dataset.request) {
          summarizeButtonClick(target);
        }
        break;
      }
    }
  }, false);
}

// Set the UI state for the summary button and content area
// statusType: 1 = loading, 2 = error, 0 = normal/finish
function setOaiState(container, statusType, statusMsg, summaryText) {
  const button = container.querySelector('.oai-summary-btn');
  const content = container.querySelector('.oai-summary-content');
  // 根据 state 设置不同的状态 (Set different states based on statusType)
  if (statusType === 1) {
    // Loading state
    container.classList.add('oai-loading');
    container.classList.remove('oai-error');
    content.innerHTML = statusMsg;
    button.disabled = true;
  } else if (statusType === 2) {
    // Error state
    container.classList.remove('oai-loading');
    container.classList.add('oai-error');
    content.innerHTML = statusMsg;
    button.disabled = false;
  } else {
    // Normal or finish state
    container.classList.remove('oai-loading');
    container.classList.remove('oai-error');
    if (statusMsg === 'finish'){
      button.disabled = false;
    }
  }

  // Debug: log the content element
  console.log(content);
  
  // If summary text is provided, render it as HTML with line breaks
  if (summaryText) {
    content.innerHTML = summaryText.replace(/(?:\r\n|\r|\n)/g, '<br>');
  }
}

// Handle click on the summary button: fetch summary parameters and dispatch to the correct provider
async function summarizeButtonClick(target) {
  var container = target.parentNode;
  // Prevent duplicate requests if already loading
  if (container.classList.contains('oai-loading')) {
    return;
  }

  setOaiState(container, 1, '加载中', null);

  // This is the address where PHP gets the parameters
  var url = target.dataset.request;
  var data = {
    ajax: true,
    _csrf: context.csrf
  };

  try {
    // Request summary parameters from backend
    const response = await axios.post(url, data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    const xresp = response.data;
    console.log(xresp);

    // Validate response structure
    if (response.status !== 200 || !xresp.response || !xresp.response.data) {
      throw new Error('请求失败 / Request Failed');
    }

    if (xresp.response.error) {
      setOaiState(container, 2, xresp.response.data, null);
    } else {
      // Parse PHP returned parameters
      const oaiParams = xresp.response.data;
      const oaiProvider = xresp.response.provider;
      // Dispatch to the correct provider handler
      if (oaiProvider === 'openai') {
        await sendOpenAIRequest(container, oaiParams);
      } else {
        await sendOllamaRequest(container, oaiParams);
      }
    }
  } catch (error) {
    console.error(error);
    setOaiState(container, 2, '请求失败 / Request Failed', null);
  }
}

// Send a streaming request to the OpenAI-compatible API and update the UI with the response
async function sendOpenAIRequest(container, oaiParams) {
  try {
    // Clone params and remove sensitive fields from body
    let body = JSON.parse(JSON.stringify(oaiParams));
    delete body['oai_url'];
    delete body['oai_key'];	  
    const response = await fetch(oaiParams.oai_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${oaiParams.oai_key}`
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      throw new Error('请求失败 / Request Failed');
    }

    // Read the streaming response
    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');

    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        setOaiState(container, 0, 'finish', null);
        break;
      }

      // Parse the chunk as JSON and extract the summary text
      const chunk = decoder.decode(value, { stream: true });
      const text = JSON.parse(chunk)?.choices[0]?.message?.content || ''
      setOaiState(container, 0, null, marked.parse(text));
    }
  } catch (error) {
    console.error(error);
    setOaiState(container, 2, '请求失败 / Request Failed', null);
  }
}


// Send a streaming request to an Ollama-compatible API and update the UI with the response
async function sendOllamaRequest(container, oaiParams){
  try {
    const response = await fetch(oaiParams.oai_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${oaiParams.oai_key}`
      },
      body: JSON.stringify(oaiParams)
    });

    if (!response.ok) {
      throw new Error('请求失败 / Request Failed');
    }
  
    // Read the streaming response
    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let text = '';
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        setOaiState(container, 0, 'finish', null);
        break;
      }
      buffer += decoder.decode(value, { stream: true });
      // Try to process complete JSON objects from the buffer (newline-delimited JSON)
      let endIndex;
      while ((endIndex = buffer.indexOf('\n')) !== -1) {
        const jsonString = buffer.slice(0, endIndex).trim();
        try {
          if (jsonString) {
            const json = JSON.parse(jsonString);
            text += json.response
            setOaiState(container, 0, null, marked.parse(text));
          }
        } catch (e) {
          // If JSON parsing fails, output the error and keep the chunk for future attempts
          console.error('Error parsing JSON:', e, 'Chunk:', jsonString);
        }
        // Remove the processed part from the buffer
        buffer = buffer.slice(endIndex + 1); // +1 to remove the newline character
      }
    }
  } catch (error) {
    console.error(error);
    setOaiState(container, 2, '请求失败 / Request Failed', null);
  }
}
