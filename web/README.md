# Web Interfaces

This directory contains all web interfaces for the FraudInvestigator AI Assistant.

## Files

### `fraud-investigator-enhanced.html`
- **Main Interface**: Most feature-rich and visually appealing
- **Features**: Animated gradients, expanded chat window, colorful design
- **Usage**: Production-ready interface for fraud investigators
- **API**: Connects to live AWS Lambda function

### `fraud-investigator-chat.html`
- **Standard Interface**: Clean, professional chat-style UI
- **Features**: Modern design, suggestion chips, typing indicators
- **Usage**: Alternative interface with balanced features
- **API**: Connects to live AWS Lambda function

### `fraud-investigator-local.html`
- **Demo Interface**: Works without API connection
- **Features**: Sample responses, offline functionality
- **Usage**: Testing and demonstration purposes
- **API**: Uses local sample data

## Usage

1. **Open any HTML file** in your web browser
2. **Type natural language queries** about fraud detection
3. **Use suggestion chips** for quick queries
4. **View real-time fraud statistics** in the dashboard

## Sample Queries

- "Show me the top 3 most suspicious transactions"
- "Which customers have the highest fraud scores?"
- "Explain why transaction TXN999004 was flagged"
- "Give me a comprehensive fraud summary"

## API Configuration

The interfaces connect to:
- **API Endpoint**: `https://cn4yjqa6ni.execute-api.us-east-1.amazonaws.com/prod/query`
- **Method**: POST
- **Content-Type**: application/json