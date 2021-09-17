import Combine
import ComposableArchitecture
import SwiftUI

struct AppState: Equatable {
    var child: ChildState?
    var childWithoutScope: ChildState?
    
    var isChildPresented: Bool {
        child != nil
    }
    
    var isChildWithoutScopePresented: Bool {
        childWithoutScope != nil
    }
}

enum AppAction: Equatable {
    case child(ChildAction)
    case childPresented(Bool)
    case childWithoutScopePresented(Bool)
}

struct ChildState: Equatable {
    var isLoading: Bool = false
}

enum ChildAction: Equatable {
    case onAppear
    case response
}

struct AppEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue> = .main
}

let childReducer = Reducer<
    ChildState,
    ChildAction,
    AppEnvironment
> { state, action, env in
    switch action {
    case .onAppear:
        state.isLoading = true
        
        return Effect(value: ChildAction.response)
            //.delay(for: 2, scheduler: env.mainQueue)
            .eraseToEffect()
    case .response:
        state.isLoading = false
        return .none
    }
}

let appReducer = Reducer<
    AppState,
    AppAction,
    AppEnvironment
>.combine(
    childReducer.optional().pullback(
        state: \.child,
        action: /AppAction.child,
        environment: { $0 }
    ),
    
    .init { state, action, env in
        switch action {
        case .child:
            return .none
        case let .childPresented(isPresented):
            state.child = isPresented ? .init() : nil
            return .none
        case let .childWithoutScopePresented(isPresented):
            state.childWithoutScope = isPresented ? .init() : nil
            return .none
        }
    }
)

struct ContentView: View {
    var body: some View {
        TabView {
            AppView(
                store: .init(
                    initialState: .init(),
                    reducer: appReducer,
                    environment: .init()
                )
            )
            .tabItem {
                Text("Demo")
            }
            
            Text("Escape")
                .tabItem {
                    Text("Escape")
                }
        }
    }
}

struct AppView: View {
    let store: Store<AppState, AppAction>
    
    @State var isVanillaChildPresented = false
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                VStack {
                    Button("show child", action: { viewStore.send(.childPresented(true)) })
                    
                    Button("show child (without scope)", action: { viewStore.send(.childWithoutScopePresented(true)) })
                    
                    Button("show child (vanilla)", action: { isVanillaChildPresented = true })
                    
                    NavigationLink(
                        isActive: viewStore.binding(
                            get: \.isChildPresented,
                            send: AppAction.childPresented
                        )
                    ) {
                        IfLetStore(store.scope(state: \.child, action: AppAction.child)) { childStore in
                            // strange behavior
                            // navigation bar still hidden on ChildView🤔
                            // (iOS 14)
                            ChildView(store: childStore)
                        }
                    } label: {
                        EmptyView()
                    }
                    
                    NavigationLink(
                        isActive: viewStore.binding(
                            get: \.isChildWithoutScopePresented,
                            send: AppAction.childWithoutScopePresented
                        )
                    ) {
                        IfLetStore(store.scope(state: \.childWithoutScope, action: AppAction.child)) { childStore in
                            // Using IfLetStore, Pass newly created store on purpose.
                            // Works fine.
                            ChildView(
                                store: .init(
                                    initialState: .init(),
                                    reducer: childReducer,
                                    environment: .init()
                                )
                            )
                        }
                    } label: {
                        EmptyView()
                    }
                    
                    NavigationLink(
                        isActive: $isVanillaChildPresented
                    ) {
                        // Works fine.
                        VanillaChildView()
                    } label: {
                        EmptyView()
                    }
                }
                .navigationBarHidden(true)
            }
        }
    }
}

struct ChildView: View {
    let store: Store<ChildState, ChildAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text("child")
                
                if viewStore.isLoading {
                    ProgressView()
                }
            }
            .onAppear { viewStore.send(.onAppear) }
            .navigationTitle("Child")
        }
    }
}

class ChildViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    
    func onAppear() {
        isLoading = true
        
        Just(false)
            .delay(for: 2, scheduler: DispatchQueue.main)
            .assign(to: &$isLoading)
    }
}

struct VanillaChildView: View {
    @StateObject var viewStore = ChildViewModel()
    
    var body: some View {
        VStack {
            Text("child")
            
            if viewStore.isLoading {
                ProgressView()
            }
        }
        .onAppear { viewStore.onAppear() }
        .navigationTitle("Child")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
