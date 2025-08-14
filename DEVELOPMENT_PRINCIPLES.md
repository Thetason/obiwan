# Software Development Principles by Masters
A curated collection of timeless software development principles from industry legends.

## Table of Contents
- [🚨 Critical Development Rules (From Real Failures)](#0-critical-development-rules-from-real-failures)
- [Martin Fowler's Refactoring Principles](#1-martin-fowlers-refactoring-principles)
- [Sajaniemi's 11 Variable Roles](#2-sajaniemis-11-variable-roles)
- [Robert Martin's Clean Code Principles](#3-robert-martins-clean-code-principles)
- [Kent Beck's TDD (Test-Driven Development)](#4-kent-becks-tdd-test-driven-development)
- [Olaf Zimmermann's Microservice API Design Patterns](#5-olaf-zimmermanns-microservice-api-design-patterns)

## 0. 🚨 Critical Development Rules (From Real Failures)

### **NEVER AGAIN: The SPICE Frequency Correction Disaster (2025-08-12)**

#### ⚠️ **What Happened**
- User sang low notes (80-150Hz) but SPICE analyzed as high notes (300-500Hz)
- Root cause: **Blind trust in existing "correction" code** that multiplied frequencies by 1.94x~3.25x
- Developer focused on symptom ("too many notes") instead of core issue ("wrong pitch entirely")

#### 🛑 **ABSOLUTE RULES - Never Break These**

##### **Rule #1: User Says "Pitch/Frequency Wrong" → Drop Everything**
```
IF user mentions:
  - "음정이 틀렸다" / "pitch is wrong"
  - "내가 낸 음과 다르다" / "not what I sang"  
  - "높게/낮게 나온다" / "too high/low"
THEN:
  1. STOP all other work
  2. Test with KNOWN frequencies immediately
  3. Trace every frequency transformation step-by-step
  4. Suspect ALL correction/calibration code first
```

##### **Rule #2: Suspect Legacy "Correction" Code Most**
```
ANY code with these keywords is GUILTY until proven innocent:
  - correctionFactor, calibration, adjustment
  - frequency * multiplier, pitch + offset
  - "compensation", "normalization"

NEVER assume it's correct because "it was working before"
```

##### **Rule #3: Log Analysis Red Flags**
```
IF you see in logs:
  - Frequency changes by 2x or more: 🚨 IMMEDIATE INVESTIGATION
  - Input: 155Hz → Output: 400Hz: 🚨 STOP EVERYTHING
  - ANY frequency transformation: 🚨 VERIFY WITH KNOWN INPUT
```

##### **Rule #4: Real User Testing is NOT Optional**
```
For ANY audio/frequency feature:
1. Test with known pure tones (440Hz, 220Hz, etc.)
2. Record yourself singing specific notes
3. Compare analysis result with what you actually sang
4. Ask user to verify results match their input

DO NOT trust unit tests alone for frequency accuracy
```

#### 💡 **Implementation Checklist**

##### Before ANY frequency-related code:
- [ ] Test with pure sine waves of known frequencies
- [ ] Log every transformation step (raw → processed → final)
- [ ] Verify no unexpected multiplications/corrections
- [ ] User validation: "Does this match what you sang?"

##### When user reports frequency issues:
- [ ] Reproduce with known test audio first
- [ ] Check ALL frequency processing pipeline
- [ ] Remove suspect "correction" code temporarily
- [ ] Test raw sensor data vs final output

#### 🎯 **Core Lesson**
**"기존 코드를 의심하고, 사용자 피드백의 핵심을 놓치지 말고, 실제 데이터로 검증하라"**
**"Doubt existing code, catch user feedback essence, verify with real data"**

---

## 1. Martin Fowler's Refactoring Principles

### Definition of Refactoring
"Refactoring is a disciplined technique for restructuring an existing body of code, altering its internal structure without changing its external behavior."

### Key Principles

#### 1.1 Two Hats
- **Adding Function**: Add new capabilities to the system
- **Refactoring**: Restructure the code without adding function
- **Never wear both hats at the same time**

#### 1.2 Refactoring Catalog
Common refactorings to apply:

- **Extract Method**: Turn a code fragment into its own method
- **Rename Variable**: Make names reveal intention
- **Move Method**: Move method to more appropriate class
- **Replace Temp with Query**: Replace temporary variables with method calls
- **Introduce Parameter Object**: Group parameters that belong together

#### 1.3 Code Smells
Signs that refactoring is needed:

- **Long Method**: Methods should be short and do one thing
- **Large Class**: Classes trying to do too much
- **Long Parameter List**: Too many parameters indicate poor abstraction
- **Duplicated Code**: Same code structure in multiple places
- **Feature Envy**: Method more interested in other class than its own

#### 1.4 When to Refactor
- **Rule of Three**: Refactor when you see duplication the third time
- **Preparatory Refactoring**: Make change easy, then make easy change
- **Comprehension Refactoring**: Refactor to understand code
- **Litter-Pickup Refactoring**: Always leave code cleaner than you found it

## 2. Sajaniemi's 11 Variable Roles
Professor Jorma Sajaniemi identified 11 stereotypical roles that variables play in programs:

### 2.1 Fixed Value
- Value doesn't change after initialization
- Example: `const MAX_SIZE = 100`

### 2.2 Stepper
- Goes through succession of values in systematic way
- Example: `for (let i = 0; i < n; i++)`

### 2.3 Flag
- Boolean variable holding state
- Example: `let isValid = true`

### 2.4 Walker
- Traverses data structure
- Example: `let current = head; while (current) { current = current.next }`

### 2.5 Most Recent Holder
- Holds latest value encountered
- Example: `let lastError = null`

### 2.6 Most Wanted Holder
- Holds best or most appropriate value found so far
- Example: `let maxValue = -Infinity`

### 2.7 Gatherer
- Accumulates values
- Example: `let sum = 0; for (x of array) sum += x`

### 2.8 Container
- Data structure holding multiple values
- Example: `const items = []`

### 2.9 Follower
- Keeps previous value of another variable
- Example: `let prev = curr; curr = next`

### 2.10 Organizer
- Rearranges or transforms data
- Example: `const sorted = array.sort()`

### 2.11 Temporary
- Holds value briefly for calculation
- Example: `const temp = a; a = b; b = temp`

## 3. Robert Martin's Clean Code Principles

### 3.1 SOLID Principles

#### S - Single Responsibility Principle
- A class should have only one reason to change
- Each module should do one thing well

#### O - Open/Closed Principle
- Open for extension, closed for modification
- Add new features by adding new code, not changing existing code

#### L - Liskov Substitution Principle
- Derived classes must be substitutable for their base classes
- Subtypes must fulfill the contract of their parent type

#### I - Interface Segregation Principle
- Many client-specific interfaces better than one general interface
- Don't force clients to depend on methods they don't use

#### D - Dependency Inversion Principle
- Depend on abstractions, not concretions
- High-level modules shouldn't depend on low-level modules

### 3.2 Clean Code Rules

#### Meaningful Names
- Use intention-revealing names
- Avoid disinformation
- Make meaningful distinctions
- Use pronounceable names
- Use searchable names

#### Functions
- Small (20 lines or less)
- Do one thing
- One level of abstraction per function
- Descriptive names
- Few arguments (ideally zero)

#### Comments
- Comments don't make up for bad code
- Explain yourself in code
- Good comments: legal, informative, explanation of intent
- Bad comments: redundant, misleading, mandated

#### Formatting
- Vertical openness between concepts
- Vertical density for related concepts
- Horizontal alignment rarely helpful
- Team rules over personal preferences

## 4. Kent Beck's TDD (Test-Driven Development)

### 4.1 TDD Cycle: Red → Green → Refactor

#### Red (Write Failing Test)
```javascript
// 1. Write test first
describe('Calculator', () => {
  it('should add two numbers correctly', () => {
    const result = add(2, 3);
    expect(result).toBe(5);
  });
});
// ❌ Test fails: add function doesn't exist
```

#### Green (Make Test Pass)
```javascript
// 2. Write minimal code to pass
function add(a: number, b: number): number {
  return a + b;
}
// ✅ Test passes
```

#### Refactor (Improve Code)
```javascript
// 3. Refactor while keeping tests green
export const add = (a: number, b: number): number => {
  validateNumbers(a, b);
  return a + b;
};

const validateNumbers = (a: number, b: number): void => {
  if (!Number.isFinite(a) || !Number.isFinite(b)) {
    throw new Error('Invalid number input');
  }
};
```

### 4.2 TDD Principles

#### Small Steps
- Write one test at a time
- Each test validates one feature
- Verify failure before success

#### Test-First Design
- Always write the test before the implementation
- Let tests drive the design
- Tests document the intended behavior

#### Refactoring Rules
- Only refactor when all tests pass
- Never add features during refactoring
- Take small steps, run tests after each

### 4.3 TDD Benefits
- Improved design through test-first thinking
- Built-in regression test suite
- Documentation through examples
- Confidence in code changes

## 5. Olaf Zimmermann's Microservice API Design Patterns

### 5.1 Foundation Patterns

#### Frontend Integration
- **Backend for Frontend (BFF)**: Dedicated backend for each frontend
- **API Gateway**: Single entry point for all clients
- **Client-Side Composition**: Frontend assembles data from multiple services

### 5.2 API Design Patterns

#### Request/Response Patterns
- **Request-Response**: Synchronous communication
- **Request-Acknowledge**: Async with acknowledgment
- **Query-Response**: Read-only operations
- **Request-Callback**: Async with callback

#### Message Patterns
- **Document Message**: Self-contained message
- **Command Message**: Invoke specific action
- **Event Message**: Notify about state change
- **Request-Reply**: Correlated messages

### 5.3 Quality Patterns

#### Performance
- **Pagination**: Return results in chunks
- **Wish List**: Client specifies desired fields
- **Conditional Request**: Use ETags for caching
- **Request Bundle**: Batch multiple requests

#### Security
- **API Key**: Simple authentication
- **OAuth 2.0**: Delegated authorization
- **Rate Limiting**: Prevent abuse
- **Circuit Breaker**: Fail fast pattern

### 5.4 Evolution Patterns

#### Versioning
- **Version Identifier**: Explicit version in API
- **Semantic Versioning**: Major.Minor.Patch
- **Two in Production**: Support current and previous
- **Aggressive Deprecation**: Clear sunset dates

#### Compatibility
- **Tolerant Reader**: Ignore unknown fields
- **Consumer-Driven Contracts**: Test from client perspective
- **Published Language**: Shared domain model
- **Context Mapper**: Manage bounded contexts

### 5.5 Implementation Guidelines
- **Design First**: API before implementation
- **Contract Testing**: Verify API contracts
- **Documentation**: OpenAPI/Swagger specs
- **Monitoring**: Track API usage and performance
- **Governance**: Consistent API standards

## Our Additional Development Rules

### Core Principles
- **NO DUMMY DATA**: Never use fake or mock data. All functionality must work with real data.
- **Real Implementation First**: Always implement actual functionality, never placeholders or simulations.
- **User-Driven Workflow**: Users must control the flow, not automatic transitions.

## References
- Fowler, M. (2018). Refactoring: Improving the Design of Existing Code (2nd ed.)
- Sajaniemi, J. (2002). An Empirical Analysis of Roles of Variables in Novice-Level Procedural Programs
- Martin, R. C. (2008). Clean Code: A Handbook of Agile Software Craftsmanship
- Beck, K. (2002). Test Driven Development: By Example
- Zimmermann, O. et al. (2022). Patterns for API Design: Simplifying Integration with Loosely Coupled Message Exchanges

---

*This document serves as our fundamental software development philosophy and must be followed in all projects. Each principle deserves deeper study and consistent application.*