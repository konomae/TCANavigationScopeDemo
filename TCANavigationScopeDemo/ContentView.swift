import Combine
import ComposableArchitecture
import SwiftUI

struct AppState: Equatable {
    var child: ChildState?
    
    var isChildPresented: Bool {
        child != nil
    }
}

enum AppAction: Equatable {
    case child(ChildAction)
    case childPresented(Bool)
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
            .delay(for: 2, scheduler: env.mainQueue)
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
        case .childPresented(true):
            state.child = .init()
            return .none
        case .childPresented(false):
            state.child = nil
            // TODO: tear down child effects
            return .none
        }
    }
)

struct ContentView: View {
    var body: some View {
        AppView(
            store: .init(
                initialState: .init(),
                reducer: appReducer,
                environment: .init()
            )
        )
    }
}

struct AppView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        NavigationView {
            VStack {
                WithViewStore(store.stateless) { viewStore in
                    Button("show child", action: { viewStore.send(.childPresented(true)) })
                }
                
                WithViewStore(store.scope(state: \.isChildPresented)) { viewStore in
                    NavigationLink(
                        isActive: viewStore.binding(
                            get: { $0 },
                            send: AppAction.childPresented
                        )
                    ) {
                        IfLetStore(
                            store.scope(state: \.child, action: AppAction.child),
                            then: ChildView.init(store:)
                        )
                    } label: {
                        EmptyView()
                    }
                }
            }
            .navigationBarHidden(true)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
