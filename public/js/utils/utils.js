function invariant(condition, message) {
  if (condition) {
    return
  }
  throw new Error(`Invariant Failure: ${message}`)
}

function invariantIsBool(value, message) {
  return invariant(typeof value === 'boolean', message);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function copyToClipboard(aid) {
  navigator.clipboard.writeText(aid)
}

function notify(notifData) {
  Alpine.store('notification').show(notifData);
}

function copyText(text, notifyData = {}) {
  copyToClipboard(text)
  notify({
    message: `Copied ${text} to Clipboard`,
    type: 'success',
    ...notifyData,
  })
}

function fileTransferSize(bytesPerSecond) {
  return `${filesize(bytesPerSecond)}/s`
}

// Remove the proxy stuff
function dd(obj) {
  return JSON.parse(JSON.stringify(obj))
}

function splitIntoChunks(str) {
  const chunks = [];

  const regexSquareBrackets = /^\[([^\[\]]*)\]/;  // Matches square brackets [content]
  const regexParentheses = /^\(([^\(\)]*)\)/;     // Matches parentheses (content)
  const regexUnencapsulated = /^[^\s_()\[\]](?:[^\[\]()]*[^\s_()\[\]])?/

  // Matches unencapsulated content
  const regexSpaces = /^[\s_]+/;                     // Matches spaces

  while (str.length > 0) {
    let match = null;

    // Try to match square brackets
    if ((match = regexSquareBrackets.exec(str))) {
      chunks.push({
        type: 'square',
        content: match[1],  // Content inside the square brackets
      });
      str = str.slice(match[0].length);  // Remove the matched part from the string
    }
    // Try to match parentheses
    else if ((match = regexParentheses.exec(str))) {
      chunks.push({
        type: 'parens',
        content: match[1],  // Content inside the parentheses
      });
      str = str.slice(match[0].length);
    }
    // Try to match spaces
    else if ((match = regexSpaces.exec(str))) {
      chunks.push({
        type: 'spaces',
        content: match[0]  // Spaces
      });
      str = str.slice(match[0].length);
    }
    // Try to match unencapsulated content
    else if ((match = regexUnencapsulated.exec(str))) {
      chunks.push({
        type: 'normal',
        content: match[0].replace(/_/g, ' '),  // Unencapsulated content
      });
      str = str.slice(match[0].length);
    } else {
      chunks.push({
        type: 'unknown',
        content: str,
      });
      break;
    }
  }
  return chunks;
}

function makeStringWithPills(str) {
  const chunks = splitIntoChunks(str);

  const textChunks = [];
  const pillChunks = [];

  for (const chunk of chunks) {
    if (chunk.type === 'spaces') {
      continue;
    }

    if (chunk.type === 'square' || chunk.type === 'parens') {
      pillChunks.push(chunk);
    } else {
      textChunks.push(chunk);
    }
  }

  return {
    textChunks,
    pillChunks,
  }
}

export {
  copyText,
  dd,
  fileTransferSize,
  invariant,
  invariantIsBool,
  notify,
  sleep,
  splitIntoChunks,
  makeStringWithPills
}

